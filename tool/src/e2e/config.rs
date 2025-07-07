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
    pub extra_dependencies: Vec<String>,
    pub meta: RepositoryMeta,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum RepositorySrc {
    GitHub(GitHubSrc),
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct GitHubSrc {
    pub full_name: String,
    pub rev: String,
    pub basedir: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct RepositoryMeta {
    pub repo_url: String,
    pub stars: u32,
    pub homepage: Option<String>,
}
