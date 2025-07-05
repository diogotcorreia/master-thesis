use std::{
    fs::{self, File},
    io::{BufReader, Write},
    path::{Path, PathBuf},
    time::{Instant, SystemTime, UNIX_EPOCH},
};

use anyhow::Result;
use flate2::bufread::GzDecoder;
use itertools::Itertools;
use serde::{Deserialize, Serialize};
use tar::Archive;
use tracing::{debug, error, info};

use crate::{
    analyse::{results::ProcessedIssues, AnalyseOptions},
    python::PipPackage,
};

use super::config::{DatasetConfig, GitHubSrc, RepositoryConfig, RepositorySrc};

const REPORTS_DIR: &str = "reports";
const TARBALLS_DIR: &str = "tarballs";
const TARBALLS_GITHUB_DIR: &str = "github";
const ANALYSIS_DIR: &str = "analysis";
const SRC_DIR: &str = "src";

pub struct Pipeline<'a> {
    work_dir: &'a Path,
    dataset_config: &'a DatasetConfig,
    pyre_path: &'a Path,
}

impl<'a> Pipeline<'a> {
    pub fn new(work_dir: &'a Path, dataset_config: &'a DatasetConfig, pyre_path: &'a Path) -> Self {
        Self {
            work_dir,
            dataset_config,
            pyre_path,
        }
    }

    pub fn run(&self) -> Result<()> {
        let total = self.dataset_config.repos.len();
        info!("Starting end-to-end pipeline on a dataset of size {total}",);

        let mut reports = vec![];
        for (i, repo) in self.dataset_config.repos.iter().enumerate() {
            let report_path = self
                .work_dir
                .join(REPORTS_DIR)
                .join(format!("{}.json", repo.id));
            if report_path.try_exists()? {
                match Self::read_existing_report(&report_path) {
                    Ok(report) => {
                        reports.push(report);
                        info!(
                            "Skipping analysing {} because report already exists",
                            repo.id
                        );
                        continue;
                    }
                    Err(error) => {
                        error!(
                            "Failed to read existing report at {report_path:?}\nError: {error:?}"
                        )
                    }
                }
            }
            info!("Analysing {} ({}/{})", repo.id, i + 1, total);
            let now = Instant::now();
            let result = self.run_repo(repo);
            let elapsed = now.elapsed();
            let report = match result {
                Ok(mut report) => {
                    report.elapsed_seconds = Some(elapsed.as_secs());
                    report
                }
                Err(error) => {
                    error!("Failed to analyse {}\nError: {error:?}", repo.id);
                    Report {
                        repository_config: repo.clone(),
                        warnings: vec![],
                        errors: vec![format!("{error:?}")],
                        issues: vec![],
                        resolved_dependencies: vec![],
                        elapsed_seconds: Some(elapsed.as_secs()),
                        previous_run: false,
                    }
                }
            };
            Self::write_report(&report_path, &report)?;
            info!("Saved report for {} at {:?}", repo.id, &report_path);
            reports.push(report);
        }

        let summary = Self::generate_summary(&reports);
        info!("Summary:\n{summary}");
        Ok(())
    }

    fn run_repo(&self, repo_config: &RepositoryConfig) -> Result<Report> {
        let destination_dir_name = {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_millis();

            format!("{}.{}", repo_config.id, now)
        };

        let project_dir = self.work_dir.join(ANALYSIS_DIR).join(destination_dir_name);
        let src_dir = project_dir.join(SRC_DIR);
        fs::create_dir_all(&src_dir)?;

        match &repo_config.src {
            RepositorySrc::GitHub(src) => {
                let tarball_path = self.download_gh_tarball(src)?;
                Self::extract_tarball(&tarball_path, &src_dir)?;

                debug!("extracted project to {src_dir:?}");
            }
        }

        let options = AnalyseOptions {
            project_dir: &project_dir,
            pyre_path: self.pyre_path,
        };
        let results = options.run_analysis()?;
        let has_issues = !results.issues.is_empty();
        let report = Report {
            repository_config: repo_config.clone(),
            warnings: results.warnings,
            errors: vec![],
            issues: results.issues,
            resolved_dependencies: results.resolved_dependencies,
            elapsed_seconds: None,
            previous_run: false,
        };

        if !has_issues {
            // remove src if nothing is found, to save disk space
            fs::remove_dir_all(src_dir)?;
            // removing deps doesn't help with storage in theory because they are hard linked by uv
        }
        Ok(report)
    }

    /// Downloads a source tarball from GitHub. Uses already downloaded tarball if it exists.
    /// The tarball is stored in the tarballs directory under the workdir.
    /// The slash in the given repo name will be replaced with a dot.
    /// If the given rev includes any slashes, they will be replaced by percent signs, since
    /// slashes are not valid file name characters in UNIX systems.
    fn download_gh_tarball(&self, src: &GitHubSrc) -> Result<PathBuf> {
        let dest_dir = self.work_dir.join(TARBALLS_DIR).join(TARBALLS_GITHUB_DIR);
        fs::create_dir_all(&dest_dir)?;
        let dest = dest_dir.join(format!(
            "{}%{}.tar.gz",
            src.full_name.replace("/", "."),
            src.rev.replace("/", "%")
        ));
        if dest.try_exists()? {
            // tarball already exists, skip downloading
            return Ok(dest);
        }
        // note: we trust the input, otherwise this can download arbitrary stuff from github
        let url = format!(
            "https://github.com/{}/archive/{}.tar.gz",
            src.full_name, src.rev
        );
        let res = reqwest::blocking::get(url)?;

        let content = res.bytes()?;
        let mut file = File::create(&dest)?;
        file.write_all(&content)?;

        debug!("Saved tarball to {dest:?}");

        Ok(dest)
    }

    fn extract_tarball(tarball_path: &Path, destination: &Path) -> Result<()> {
        let tar_gz = File::open(tarball_path)?;
        let tar = GzDecoder::new(BufReader::new(tar_gz));
        let mut archive = Archive::new(tar);
        archive.unpack(destination)?;

        let mut dir = destination.read_dir()?;
        match (dir.next(), dir.next()) {
            (Some(Ok(file)), None) if file.file_type()?.is_dir() => {
                // tar contained a single directory, move it up to be src instead
                let tmp_dir = destination.parent().unwrap().join("src_tmp");
                fs::rename(file.path(), &tmp_dir)?;
                fs::remove_dir(destination)?;
                fs::rename(&tmp_dir, destination)?;
            }
            _ => {}
        }
        Ok(())
    }

    fn read_existing_report(report_path: &Path) -> Result<Report> {
        let file = File::open(report_path)?;
        let bufreader = BufReader::new(file);
        Ok(serde_json::from_reader(bufreader)?)
    }

    fn write_report(report_path: &Path, report: &Report) -> Result<()> {
        if let Some(parent) = report_path.parent() {
            fs::create_dir_all(parent)?;
        }
        let file = File::create(report_path)?;
        serde_json::to_writer(file, report)?;
        Ok(())
    }

    fn generate_summary(reports: &[Report]) -> String {
        let no_issues: Vec<_> = reports
            .iter()
            .filter(|r| r.outcome() == ReportOutcome::NoIssues)
            .collect();
        let issues: Vec<_> = reports
            .iter()
            .filter(|r| r.outcome() == ReportOutcome::Issues)
            .collect();
        let warnings: Vec<_> = reports
            .iter()
            .filter(|r| r.outcome() == ReportOutcome::Warnings)
            .collect();
        let errors: Vec<_> = reports
            .iter()
            .filter(|r| r.outcome() == ReportOutcome::Errors)
            .collect();

        format!(
            r"# Report Summary

## Packages with class pollution issues ({})

{}

## Packages with errors ({})

{}

## Packages with warnings ({})

{}

## Packages with no issues ({})

{}
            ",
            issues.len(),
            issues
                .iter()
                .map(|r| format!(
                    "- {} ({} issue(s)){}",
                    r.repository_config.id,
                    r.issues.len(),
                    if r.previous_run { " (cached)" } else { "" }
                ))
                .join("\n"),
            errors.len(),
            errors
                .iter()
                .map(|r| format!(
                    "- {} ({} error(s)){}",
                    r.repository_config.id,
                    r.errors.len(),
                    if r.previous_run { " (cached)" } else { "" }
                ))
                .join("\n"),
            warnings.len(),
            warnings
                .iter()
                .map(|r| format!(
                    "- {} ({} warning(s), {} issue(s)){}",
                    r.repository_config.id,
                    r.warnings.len(),
                    r.issues.len(),
                    if r.previous_run { " (cached)" } else { "" }
                ))
                .join("\n"),
            no_issues.len(),
            no_issues
                .iter()
                .map(|r| format!(
                    "- {}{}",
                    r.repository_config.id,
                    if r.previous_run { " (cached)" } else { "" }
                ))
                .join("\n"),
        )
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Report {
    pub repository_config: RepositoryConfig,
    pub warnings: Vec<String>, // TODO make this a proper enum
    pub errors: Vec<String>,
    pub issues: Vec<ProcessedIssues>,
    pub resolved_dependencies: Vec<PipPackage>,
    pub elapsed_seconds: Option<u64>,
    /// Whether this report comes from a previous run, that is, it was read from the file system
    /// instead of the analysis being done now.
    #[serde(skip, default = "Report::_true")]
    pub previous_run: bool,
}

impl Report {
    pub fn outcome(&self) -> ReportOutcome {
        if !self.errors.is_empty() {
            ReportOutcome::Errors
        } else if !self.warnings.is_empty() {
            ReportOutcome::Warnings
        } else if !self.issues.is_empty() {
            ReportOutcome::Issues
        } else {
            ReportOutcome::NoIssues
        }
    }

    /// For serde default field
    fn _true() -> bool {
        true
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReportOutcome {
    NoIssues,
    Issues,
    Warnings,
    Errors,
}
