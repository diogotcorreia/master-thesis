use serde::{Deserialize, Serialize};

use crate::python::deps::ResolveDependenciesOpts;

#[derive(Debug, Default, Deserialize)]
#[serde(default)]
pub struct DatasetConfig {
    pub resolve_dependencies_opts: ResolveDependenciesOpts,
    pub repos: Vec<RepositoryConfig>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct RepositoryConfig {
    pub id: String,
    pub src: RepositorySrc,
    #[serde(default)]
    pub extra_dependencies: Vec<String>,
    pub meta: RepositoryMeta,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum RepositorySrc {
    GitHub(GitHubSrc),
    PyPI(PyPISrc),
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct GitHubSrc {
    pub full_name: String,
    pub rev: String,
    pub basedir: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct PyPISrc {
    pub name: Option<String>,
    pub version: Option<String>,
    pub download_url: String,
    pub filename: String,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct RepositoryMeta {
    pub repo_url: Option<String>,
    pub stars: Option<u32>,
    pub downloads: Option<u32>,
    pub homepage: Option<String>,
}
