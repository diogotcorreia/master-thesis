use std::{
    cmp::Ordering,
    collections::HashMap,
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
use tracing::{debug, error, info, warn};

use crate::analyse::results::{IssueLabel, NotVulnerableReason, ProcessedIssue};

use super::{
    config::DatasetConfig,
    pipeline::{Report, ANALYSIS_DIR},
    AllowedRepos,
};

pub struct Labeling<'a> {
    work_dir: &'a Path,
    allowed_repos: AllowedRepos,
}

impl<'a> Labeling<'a> {
    pub fn new(work_dir: &'a Path, dataset: Option<&DatasetConfig>) -> Self {
        let allowed_repos = AllowedRepos::from(dataset);

        Labeling {
            work_dir,
            allowed_repos,
        }
    }

    pub fn prompt_unlabeled(&self) -> Result<()> {
        let reports = self.list_reports()?;
        let all_analysis = self.list_analysis()?;

        let report_count = reports.len();
        for (i, (id, report_path)) in reports.iter().enumerate() {
            let report = match Report::read(report_path) {
                Ok(report) => report,
                Err(error) => {
                    error!("Failed to open report {:?}\nError: {error:?}", report_path);
                    continue;
                }
            };
            let analysis_dir = Self::find_analysis_directory(&all_analysis, id);

            let Some(dir) = analysis_dir else {
                warn!("Could not find the analysis directory for {}", id);
                continue;
            };
            if let Some(updated_report) = self.prompt_project(id, dir, report, (i, report_count)) {
                updated_report.write(report_path)?;
                debug!("Saved updated report to {:?}", &report_path);
            }
        }

        Ok(())
    }

    fn list_reports(&self) -> Result<Vec<(String, PathBuf)>> {
        crate::e2e::list_reports(self.work_dir, &self.allowed_repos)
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
        let id_dot = format!("{id}.");
        let index = all_analysis.binary_search_by(|(dir_name, _)| {
            let Some((dep_id, _)) = dir_name.rsplit_once(".") else {
                return Ordering::Less;
            };
            dep_id.cmp(&id_dot).then(Ordering::Less)
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
    fn prompt_project(
        &self,
        id: &str,
        analysis_dir: &Path,
        mut report: Report,
        index: (usize, usize),
    ) -> Option<Report> {
        debug!(
            "Looking for unlabeled issues (project {}/{})",
            index.0 + 1,
            index.1
        );
        let mut changed = false;
        let count = report.issues.len();
        for (i, issue) in report.issues.iter_mut().enumerate() {
            if let IssueLabel::Unlabeled = issue.label {
                match Self::prompt_issue(analysis_dir, issue, (i, count)) {
                    Ok(_) => changed = true,
                    Err(error) => {
                        error!("Failed to prompt issue\nError: {error:?}");
                    }
                }
            }
        }

        changed.then_some(report)
    }

    fn prompt_issue(
        analysis_dir: &Path,
        issue: &mut ProcessedIssue,
        index: (usize, usize),
    ) -> Result<()> {
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
            let (style, message) = if trace.callable == "getattr" {
                (
                    LabelStyle::Primary,
                    "the return value of getattr becomes tainted",
                )
            } else if trace.callable == "setattr" {
                (
                    LabelStyle::Primary,
                    "the first argument of setattr is tainted",
                )
            } else {
                (LabelStyle::Secondary, "taint propagates")
            };
            labels.push(label!(style, trace.location).with_message(format!(
                "#{}: {}",
                i + 1,
                message
            )));
        }
        let diagnostic = Diagnostic::warning()
            .with_message("found potential class pollution")
            .with_labels(labels);

        term::emit(&mut writer.lock(), &term_config, &files, &diagnostic)
            .context("failed to show pyre issue")?;

        info!("Looking at issue {}/{}", index.0 + 1, index.1);

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
                NotVulnerableReason::AttrAllowList,
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
