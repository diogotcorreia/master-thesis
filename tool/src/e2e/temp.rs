use std::{
    cmp::Ordering,
    path::{Path, PathBuf},
};

use anyhow::{anyhow, Context, Result};
use itertools::Itertools;
use tracing::{debug, error, warn};

use crate::analyse::{results::UnprocessedResults, PYSA_RESULTS_DIR};

use super::{
    config::DatasetConfig,
    pipeline::{Report, ANALYSIS_DIR},
    AllowedRepos,
};

pub struct Temp<'a> {
    work_dir: &'a Path,
    allowed_repos: AllowedRepos,
}

impl<'a> Temp<'a> {
    pub fn new(work_dir: &'a Path, dataset: Option<&DatasetConfig>) -> Self {
        let allowed_repos = AllowedRepos::from(dataset);

        Temp {
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
            if let Some(updated_report) = self.prompt_project(id, dir, report, (i, report_count))? {
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
            let Some(i) = dir_name.rfind(".") else {
                return Ordering::Less;
            };
            let dep_id = &dir_name[..(i + 1)];
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
    ) -> Result<Option<Report>> {
        debug!("Fixing results (project {}/{})", index.0 + 1, index.1);

        let results = UnprocessedResults::from_results_dir(&analysis_dir.join(PYSA_RESULTS_DIR))
            .context("failed to parse results")?;

        let results = results.process();

        let mut changed = false;
        for issue in results.issues {
            let mut old_issue = report
                .issues
                .iter_mut()
                .filter(|iss| iss.trace == issue.trace)
                .collect_vec();
            if old_issue.len() != 1 {
                return Err(anyhow!(
                    "failed to find existing issue n={}",
                    old_issue.len()
                ));
            }
            let i = old_issue.remove(0);
            if i.getattr_count != issue.getattr_count {
                debug!(
                    "Updated getattr_count from {:?} to {:?}",
                    i.getattr_count, issue.getattr_count
                );
                i.getattr_count = issue.getattr_count;
                changed = true;
            }
        }

        Ok(changed.then_some(report))
    }
}
