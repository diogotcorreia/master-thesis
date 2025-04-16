use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct PyreConfiguration {
    pub site_package_search_strategy: SitePackageSearchStrategy,
    pub source_directories: Vec<String>,
    pub taint_models_path: Vec<String>,
    pub site_roots: Vec<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum SitePackageSearchStrategy {
    None,
    All,
    Pep561,
}

#[derive(Debug, Serialize)]
pub struct TaintConfig {
    pub sources: Vec<TaintEntry>,
    pub sinks: Vec<TaintEntry>,
    pub features: Vec<TaintEntry>,
    pub rules: Vec<TaintRule>,
    pub options: TaintOptions,
}

#[derive(Debug, Serialize)]
pub struct TaintEntry {
    pub name: String,
}

#[derive(Debug, Serialize)]
pub struct TaintRule {
    pub name: String,
    pub code: u32,
    pub sources: Vec<String>,
    pub sinks: Vec<String>,
    pub message_format: String,
}

#[derive(Debug, Serialize)]
pub struct TaintOptions {
    pub maximum_overrides_to_analyze: u32,
    pub maximum_trace_length: u32,
}
