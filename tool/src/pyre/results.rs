use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct TaintOutputHeader {
    pub file_version: u32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase", tag = "kind", content = "data")]
pub enum TaintOutput {
    Issue(TaintIssueData),
    Model {},
}

#[derive(Debug, Deserialize)]
pub struct TaintIssueData {
    pub traces: Vec<TaintTraces>,
    #[serde(flatten)]
    pub location: SpanLocation,
}

#[derive(Debug, Deserialize)]
pub struct TaintTraces {
    pub name: String,
    pub roots: Vec<TaintRoot>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum TaintRoot {
    Origin(TaintRootOrigin),
    Call(TaintRootCall),
}

#[derive(Debug, Deserialize)]
pub struct TaintRootOrigin {
    pub kinds: Vec<RootKind>,
    #[serde(default)]
    pub local_features: Vec<LocalFeature>,
    pub origin: SpanLocation,
}

#[derive(Debug, Deserialize)]
pub struct TaintRootCall {
    pub kinds: Vec<RootKind>,
    #[serde(default)]
    pub local_features: Vec<LocalFeature>,
    pub call: TaintCall,
}

#[derive(Debug, Deserialize)]
pub struct RootKind {
    pub kind: String,
    #[serde(default)]
    pub features: Vec<LocalFeature>,
}

#[derive(Debug, Deserialize)]
pub struct TaintCall {
    pub position: SpanLocation,
    pub resolves_to: Vec<String>,
    pub port: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct LocalFeature {
    pub always_via: Option<String>,
    pub always_via_get_name_value: Option<String>,
    pub always_via_set_name_value: Option<String>,
    pub always_via_set_value_value: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct SpanLocation {
    pub filename: String,
    pub path: Option<String>,
    pub line: u32,
    pub start: u32,
    pub end: u32,
}
