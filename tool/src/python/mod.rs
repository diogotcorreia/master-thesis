use std::collections::HashMap;

use serde::{de::IgnoredAny, Deserialize, Serialize};

pub mod deps;

// https://peps.python.org/pep-0751/
#[derive(Debug, Deserialize, Default)]
pub struct PyLock {
    #[serde(default)]
    pub packages: Vec<PipPackage>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PipPackage {
    pub name: String,
    pub version: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct PyProject {
    // https://peps.python.org/pep-0735/
    dependency_groups: HashMap<String, IgnoredAny>,
}
