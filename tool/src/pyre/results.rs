use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct TaintOutputHeader {
    pub file_version: u32,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase", tag = "kind", content = "data")]
pub enum TaintOutput {
    Issue(TaintIssueData),
    Model(TaintModelData),
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintIssueData {
    pub callable: String,
    pub traces: Vec<TaintIssueTraces>,
    #[serde(flatten)]
    pub location: SpanLocation,
    #[serde(default)]
    pub features: Vec<LocalFeature>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintModelData {
    pub callable: String,
    pub filename: Option<String>,
    pub path: Option<String>,
    #[serde(default)]
    pub sources: Vec<TaintTrace>,
    #[serde(default)]
    pub sinks: Vec<TaintTrace>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintIssueTraces {
    pub name: String,
    pub roots: Vec<TraceFragment>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(untagged)]
pub enum TraceFragment {
    Origin(TaintRootOrigin),
    Call(TaintRootCall),
    Declaration(TaintRootDeclaration),
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
pub struct TaintRootDeclaration {
    pub declaration: (),
}

#[derive(Debug, Deserialize, Serialize)]
pub struct RootKind {
    pub kind: String,
    #[serde(default)]
    pub features: Vec<LocalFeature>,
    #[serde(default)]
    pub leaves: Vec<KindLeaf>,
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
pub struct KindLeaf {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub port: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SpanLocation {
    pub filename: Option<String>,
    pub path: Option<String>,
    pub line: u32,
    pub start: u32,
    pub end: u32,
}

impl SpanLocation {
    pub fn with_filename(&self, filename: String) -> Self {
        let mut loc = self.clone();
        loc.filename = Some(filename);
        loc
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct TaintTrace {
    pub port: String,
    pub taint: Vec<TraceFragment>,
}

impl TaintIssueData {
    pub fn has_via_feature(&self, value: &str) -> bool {
        self.features.iter().any(|feature| {
            feature.via.iter().any(|v| value == v) || feature.always_via.iter().any(|v| value == v)
        })
    }
}

impl TraceFragment {
    pub fn kinds(&self) -> &[RootKind] {
        match self {
            TraceFragment::Origin(taint_root_origin) => &taint_root_origin.kinds,
            TraceFragment::Call(taint_root_call) => &taint_root_call.kinds,
            TraceFragment::Declaration(_) => &[],
        }
    }
    pub fn local_features(&self) -> &[LocalFeature] {
        match self {
            TraceFragment::Origin(taint_root_origin) => &taint_root_origin.local_features,
            TraceFragment::Call(taint_root_call) => &taint_root_call.local_features,
            TraceFragment::Declaration(_) => &[],
        }
    }
}
