use serde::{Deserialize, Serialize};

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
