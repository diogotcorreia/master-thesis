use std::{
    cmp::Ordering,
    collections::HashMap,
    ffi::OsStr,
    fs,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use codespan_reporting::{
    diagnostic::{Diagnostic, Label, LabelStyle},
    files::{Files, SimpleFiles},
    term::{
        self,
        termcolor::{ColorChoice, StandardStream},
    },
};
use inquire::{MultiSelect, Select, Text};
use itertools::Itertools;
use tracing::{debug, error, warn};

use crate::analyse::results::{IssueLabel, NotVulnerableReason, ProcessedIssue};

use super::{
    config::DatasetConfig,
    pipeline::{Report, ANALYSIS_DIR, REPORTS_DIR},
};

pub struct Labeling<'a> {
    work_dir: &'a Path,
    allowed_repos: AllowedRepos,
}

impl<'a> Labeling<'a> {
    pub fn new(work_dir: &'a Path, dataset: Option<&DatasetConfig>) -> Self {
        let allowed_repos = if let Some(dataset) = dataset {
            let ids = dataset.repos.iter().map(|r| r.id.clone()).collect_vec();
            AllowedRepos::new_filtered(ids)
        } else {
            AllowedRepos::new_all()
        };

        Labeling {
            work_dir,
            allowed_repos,
        }
    }

    pub fn prompt_unlabeled(&self) -> Result<()> {
        let reports = self.list_reports()?;
        let all_analysis = self.list_analysis()?;

        for (id, report_path) in reports {
            let report = match Report::read(&report_path) {
                Ok(report) => report,
                Err(error) => {
                    error!("Failed to open report {:?}\nError: {error:?}", &report_path);
                    continue;
                }
            };
            let analysis_dir = Self::find_analysis_directory(&all_analysis, &id);

            let Some(dir) = analysis_dir else {
                warn!("Could not find the analysis directory for {}", id);
                continue;
            };
            if let Some(updated_report) = self.prompt_project(&id, dir, report) {
                updated_report.write(&report_path)?;
                debug!("Saved updated report to {:?}", &report_path);
            }
        }

        Ok(())
    }

    fn list_reports(&self) -> Result<Vec<(String, PathBuf)>> {
        let reports_dir = self.work_dir.join(REPORTS_DIR);
        if !reports_dir.is_dir() {
            return Ok(Vec::new());
        }

        let dir = reports_dir.read_dir()?;

        Ok(dir.process_results(|iter| {
            iter.map(|file| file.path())
                .filter(|path| path.is_file())
                .filter(|path| path.extension() == Some(OsStr::new("json")))
                .filter_map(|path| {
                    let stem = path.file_stem()?.to_str()?;
                    Some((stem.to_string(), path)).filter(|(s, _)| self.allowed_repos.is_allowed(s))
                })
                .collect_vec()
        })?)
    }

    fn list_analysis(&self) -> Result<Vec<(String, PathBuf)>> {
        let analysis_dir = self.work_dir.join(ANALYSIS_DIR);
        if !analysis_dir.is_dir() {
            return Ok(Vec::new());
        }

        let dir = analysis_dir.read_dir()?;

        Ok(dir.process_results(|iter| {
            iter.map(|file| file.path())
                .filter(|path| path.is_dir())
                .filter_map(|path| Some((path.file_name()?.to_str()?.to_string(), path)))
                .sorted()
                .collect_vec()
        })?)
    }

    fn find_analysis_directory<'b>(
        all_analysis: &'b [(String, PathBuf)],
        id: &str,
    ) -> Option<&'b Path> {
        let index = all_analysis.binary_search_by(|(dir_name, _)| {
            let Some((dep_id, _)) = dir_name.rsplit_once(".") else {
                return Ordering::Less;
            };
            dep_id.cmp(id).then(Ordering::Less)
        });
        match index {
            Ok(_) => unreachable!(),
            Err(index) => {
                let index = index.checked_sub(1)?;
                let (dir_name, path) = all_analysis.get(index)?;
                let (dep_id, _) = dir_name.rsplit_once(".")?;
                (dep_id == id).then_some(path)
            }
        }
    }

    #[tracing::instrument(skip(self, report))]
    fn prompt_project(&self, id: &str, analysis_dir: &Path, mut report: Report) -> Option<Report> {
        debug!("Looking for unlabeled issues");
        let mut changed = false;
        for issue in report.issues.iter_mut() {
            if let IssueLabel::Unlabeled = issue.label {
                match Self::prompt_issue(analysis_dir, issue) {
                    Ok(_) => changed = true,
                    Err(error) => {
                        error!("Failed to prompt issue\nError: {error:?}");
                    }
                }
            }
        }

        changed.then_some(report)
    }

    fn prompt_issue(analysis_dir: &Path, issue: &mut ProcessedIssue) -> Result<()> {
        let writer = StandardStream::stderr(ColorChoice::Auto);
        let term_config = term::Config {
            before_label_lines: 100,
            after_label_lines: 50,
            ..Default::default()
        };
        let mut files = SimpleFiles::new();
        let mut files_read: HashMap<String, usize> = HashMap::new();

        macro_rules! get_file_id {
            ($file: expr) => {{
                match files_read.get($file) {
                    Some(id) => std::io::Result::Ok(*id),
                    None => {
                        let file_path = analysis_dir.join($file);
                        let contents = fs::read_to_string(file_path)?;
                        let id = files.add($file.to_string(), contents);
                        files_read.insert($file.to_string(), id);
                        Ok(id)
                    }
                }
            }};
        }

        macro_rules! label {
            ($style: expr, $location: expr) => {{
                let file = $location.get_filename().unwrap_or_default();
                let id = get_file_id!(file)?;
                let line_range = files.line_range(id, $location.line as usize - 1)?;
                let line_start = line_range.start;
                let start = line_start + $location.start as usize;
                let end = line_start + $location.end as usize;
                Label::new($style, id, start..end)
            }};
        }

        let mut labels = Vec::new();
        labels.push(
            label!(LabelStyle::Primary, issue.location)
                .with_message("forward and backward traces meet here"),
        );
        for (i, trace) in issue.trace.iter().enumerate() {
            let message = if trace.callable == "getattr" {
                "the return value of getattr becomes tainted"
            } else if trace.callable == "setattr" {
                "the first argument of setattr is tainted"
            } else {
                "taint propagates"
            };
            labels.push(
                label!(LabelStyle::Secondary, trace.location).with_message(format!(
                    "#{}: {}",
                    i + 1,
                    message
                )),
            );
        }
        let diagnostic = Diagnostic::warning()
            .with_message("found potential class pollution")
            .with_labels(labels);

        term::emit(&mut writer.lock(), &term_config, &files, &diagnostic)
            .context("failed to show pyre issue")?;

        let options = vec![
            IssueLabel::Unlabeled,
            IssueLabel::Vulnerable,
            IssueLabel::NotVulnerable { reasons: vec![] },
        ];

        let mut label = Select::new("Select label to apply to this issue:", options).prompt()?;

        if let IssueLabel::NotVulnerable { reasons } = &mut label {
            let options = vec![
                NotVulnerableReason::ModifiedReference,
                NotVulnerableReason::NonRecursive,
                NotVulnerableReason::Filtered,
                NotVulnerableReason::NotControlled,
                NotVulnerableReason::Other {
                    notes: "".to_string(),
                },
            ];
            let mut selected_reasons =
                MultiSelect::new("Why is this not vulnerable?", options).prompt()?;
            for reason in selected_reasons.iter_mut() {
                if let NotVulnerableReason::Other { notes } = reason {
                    *notes = Text::new("What's the reason for this issue to not be vulnerable?")
                        .prompt()?;
                }
            }
            *reasons = selected_reasons;
        }

        issue.label = label;

        Ok(())
    }
}

enum AllowedRepos {
    All,
    Filtered(Vec<String>),
}

impl AllowedRepos {
    fn new_all() -> Self {
        Self::All
    }
    fn new_filtered(mut ids: Vec<String>) -> Self {
        ids.sort();
        AllowedRepos::Filtered(ids)
    }

    fn is_allowed(&self, id: &str) -> bool {
        match self {
            AllowedRepos::All => true,
            AllowedRepos::Filtered(items) => items
                .binary_search_by_key(&id, |item| item.as_str())
                .is_ok(),
        }
    }
}
