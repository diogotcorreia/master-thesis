use serde::{Deserialize, Serialize};

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

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintIssueData {
    pub traces: Vec<TaintTraces>,
    #[serde(flatten)]
    pub location: SpanLocation,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintTraces {
    pub name: String,
    pub roots: Vec<TaintRoot>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(untagged)]
pub enum TaintRoot {
    Origin(TaintRootOrigin),
    Call(TaintRootCall),
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintRootOrigin {
    pub kinds: Vec<RootKind>,
    #[serde(default)]
    pub local_features: Vec<LocalFeature>,
    pub origin: SpanLocation,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintRootCall {
    pub kinds: Vec<RootKind>,
    #[serde(default)]
    pub local_features: Vec<LocalFeature>,
    pub call: TaintCall,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct RootKind {
    pub kind: String,
    #[serde(default)]
    pub features: Vec<LocalFeature>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintCall {
    pub position: SpanLocation,
    pub resolves_to: Vec<String>,
    pub port: String,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "kebab-case")]
pub struct LocalFeature {
    pub via: Option<String>,
    pub always_via: Option<String>,
    pub always_via_get_name_value: Option<String>,
    pub always_via_set_name_value: Option<String>,
    pub always_via_set_value_value: Option<String>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct SpanLocation {
    pub filename: String,
    pub path: Option<String>,
    pub line: u32,
    pub start: u32,
    pub end: u32,
}

impl TaintRoot {
    pub fn kinds(&self) -> &[RootKind] {
        match self {
            TaintRoot::Origin(taint_root_origin) => &taint_root_origin.kinds,
            TaintRoot::Call(taint_root_call) => &taint_root_call.kinds,
        }
    }
    pub fn local_features(&self) -> &[LocalFeature] {
        match self {
            TaintRoot::Origin(taint_root_origin) => &taint_root_origin.local_features,
            TaintRoot::Call(taint_root_call) => &taint_root_call.local_features,
        }
    }
}
