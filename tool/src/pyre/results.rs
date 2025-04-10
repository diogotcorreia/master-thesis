use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase", tag = "kind", content = "data")]
pub enum TaintOutput {
    Issue(TaintIssueData),
    #[serde(untagged)]
    Other {},
}

#[derive(Debug, Deserialize)]
pub struct TaintIssueData {
    pub traces: Vec<TaintTraces>,
}

#[derive(Debug, Deserialize)]
pub struct TaintTraces {
    pub name: String,
    pub roots: Vec<TaintRoot>,
}

#[derive(Debug, Deserialize)]
pub struct TaintRoot {
    pub kinds: Vec<RootKind>,
    pub local_features: Vec<LocalFeature>,
    pub origin: SpanOrigin,
}

#[derive(Debug, Deserialize)]
pub struct RootKind {
    pub kind: String,
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
pub struct SpanOrigin {
    pub filename: String,
    pub line: u32,
    pub start: u32,
    pub end: u32,
}
