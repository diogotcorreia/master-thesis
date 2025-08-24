use std::{
    fs::File,
    path::{Path, PathBuf},
};

use anyhow::{Context, Result};
use itertools::Itertools;
use serde::Serialize;
use tracing::info;

use crate::{
    analyse::results::{GetAttrCount, IssueLabel, ProcessedIssue},
    errors::PipelineStage,
};

use super::{
    config::{DatasetConfig, RepositorySrc},
    pipeline::Report,
    AllowedRepos,
};

const SUMMARY_JSON: &str = "summary.json";

pub struct Summary<'a> {
    work_dir: &'a Path,
    allowed_repos: AllowedRepos,
}

impl<'a> Summary<'a> {
    pub fn new(work_dir: &'a Path, dataset: Option<&DatasetConfig>) -> Self {
        let allowed_repos = AllowedRepos::from(dataset);

        Summary {
            work_dir,
            allowed_repos,
        }
    }

    pub fn compile_summary_json(&self) -> Result<()> {
        let reports = self.list_reports()?;

        info!("Loading {} report(s)", reports.len());

        let summary: Vec<SummaryEntry> = reports
            .iter()
            .map(|(_, report_path)| {
                Report::read(report_path)
                    .with_context(|| format!("failed to open report {report_path:?}"))
            })
            .process_results(|it| it.map(|report| report.into()).collect())?;

        let summary_path = self.work_dir.join(SUMMARY_JSON);
        let file = File::create(&summary_path)?;
        serde_json::to_writer(file, &summary)?;

        info!("Wrote summary to {:?}", &summary_path);

        Ok(())
    }

    fn list_reports(&self) -> Result<Vec<(String, PathBuf)>> {
        crate::e2e::list_reports(self.work_dir, &self.allowed_repos)
    }
}

#[derive(Debug, Serialize)]
struct SummaryEntry {
    platform: Platform,
    name: String,
    popularity: u32, // stars or downloads
    error_stage: Option<PipelineStage>,
    raw_issue_count: usize,
    issues: Vec<IssueSummary>,
    elapsed_seconds: Option<u64>,
}

impl From<Report> for SummaryEntry {
    fn from(report: Report) -> Self {
        let (platform, name, popularity) = match report.repository_config.src {
            RepositorySrc::GitHub(github_src) => (
                Platform::GitHub,
                github_src.full_name,
                report.repository_config.meta.stars.unwrap_or_default(),
            ),
            RepositorySrc::PyPI(pypi_src) => (
                Platform::PyPI,
                pypi_src.name.unwrap_or_default(),
                report.repository_config.meta.downloads.unwrap_or_default(),
            ),
        };
        Self {
            platform,
            name,
            popularity,
            error_stage: report.error_stage,
            raw_issue_count: report.raw_issue_count,
            issues: report
                .issues
                .into_iter()
                .map(|issue| issue.into())
                .collect(),
            elapsed_seconds: report.elapsed_seconds,
        }
    }
}

#[derive(Debug, Serialize)]
enum Platform {
    GitHub,
    PyPI,
}

#[derive(Debug, Serialize)]
struct IssueSummary {
    getattr_count: GetAttrCount,
    label: IssueLabel,
}

impl From<ProcessedIssue> for IssueSummary {
    fn from(issue: ProcessedIssue) -> Self {
        Self {
            getattr_count: issue.getattr_count,
            label: issue.label,
        }
    }
}
