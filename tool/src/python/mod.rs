use serde::Deserialize;

// https://peps.python.org/pep-0751/
#[derive(Debug, Deserialize, Default)]
pub struct PyLock {
    pub packages: Vec<PipPackage>,
}

#[derive(Debug, Deserialize)]
pub struct PipPackage {
    pub name: String,
    pub version: Option<String>,
}
