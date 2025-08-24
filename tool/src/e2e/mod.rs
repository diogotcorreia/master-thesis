use std::{
    ffi::OsStr,
    path::{Path, PathBuf},
};

use anyhow::Result;
use config::DatasetConfig;
use itertools::Itertools;
use pipeline::REPORTS_DIR;

pub mod config;
pub mod labeling;
pub mod pipeline;
pub mod summary;

pub enum AllowedRepos {
    All,
    Filtered(Vec<String>),
}

impl AllowedRepos {
    pub fn new_all() -> Self {
        Self::All
    }
    pub fn new_filtered(mut ids: Vec<String>) -> Self {
        ids.sort();
        AllowedRepos::Filtered(ids)
    }

    pub fn is_allowed(&self, id: &str) -> bool {
        match self {
            AllowedRepos::All => true,
            AllowedRepos::Filtered(items) => items
                .binary_search_by_key(&id, |item| item.as_str())
                .is_ok(),
        }
    }
}

impl From<Option<&DatasetConfig>> for AllowedRepos {
    fn from(dataset: Option<&DatasetConfig>) -> Self {
        if let Some(dataset) = dataset {
            let ids = dataset.repos.iter().map(|r| r.id.clone()).collect_vec();
            AllowedRepos::new_filtered(ids)
        } else {
            AllowedRepos::new_all()
        }
    }
}

fn list_reports(work_dir: &Path, allowed_repos: &AllowedRepos) -> Result<Vec<(String, PathBuf)>> {
    let reports_dir = work_dir.join(REPORTS_DIR);
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
                Some((stem.to_string(), path)).filter(|(s, _)| allowed_repos.is_allowed(s))
            })
            .collect_vec()
    })?)
}
