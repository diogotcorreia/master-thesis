use std::{
    fmt::{Display, Write},
    fs::File,
    io::{BufRead, BufReader},
    path::Path,
};

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::{
    errors::ToolError,
    pyre::results::{
        SpanLocation, TaintIssueData, TaintModelData, TaintOutput, TaintOutputHeader, TraceFragment,
    },
    python::PipPackage,
};

const PYSA_TAINT_OUTPUT_NAME: &str = "taint-output.json";
const PYSA_TAINT_OUTPUT_SUPPORTED_VERSION: u32 = 3;

#[derive(Debug)]
pub struct UnprocessedResults {
    pub models: Vec<TaintModelData>,
    pub issues: Vec<TaintIssueData>,
    pub raw_issue_count: usize,
}

impl UnprocessedResults {
    #[tracing::instrument]
    pub fn from_results_dir(results_dir: &Path) -> Result<Self> {
        let file = File::open(results_dir.join(PYSA_TAINT_OUTPUT_NAME))?;
        let mut reader = BufReader::new(file);
        let mut header = String::new();
        reader.read_line(&mut header)?; // skip file header
        let header: TaintOutputHeader = serde_json::from_str(&header)?;

        if header.file_version != PYSA_TAINT_OUTPUT_SUPPORTED_VERSION {
            return Err(ToolError::PyreResultVersionMismatch {
                got: header.file_version,
                expected: PYSA_TAINT_OUTPUT_SUPPORTED_VERSION,
            }
            .into());
        }

        let mut models = vec![];
        let mut issues = vec![];
        let mut raw_issue_count = 0usize;
        for entry in serde_json::Deserializer::from_reader(reader).into_iter() {
            match entry? {
                TaintOutput::Model(data) => models.push(data),
                TaintOutput::Issue(data) => {
                    // Issues with feature `tito-broadening` or `obscure:model` usually mean the
                    // taint flows indirectly or that the result of getattr is manipulated in
                    // some way before being passed to setattr, which does not yield a class
                    // pollution vulnerability.
                    if !data.has_via_feature("tito-broadening")
                        && !data.has_via_feature("obscure:model")
                    {
                        issues.push(data)
                    }

                    raw_issue_count += 1;
                }
            }
        }

        // allow for binary search later
        models.sort_by_cached_key(|model| model.callable.clone());

        Ok(UnprocessedResults {
            models,
            issues,
            raw_issue_count,
        })
    }

    pub fn process(&self) -> ProcessedResults {
        let issues = self
            .issues
            .iter()
            .map(|issue_data| {
                let getattr_count = GetAttrCount::from_issue_data(issue_data);

                let mut traces = vec![];

                let backward_traces = issue_data
                    .traces
                    .iter()
                    .find(|t| t.name == "backward")
                    .map(|t| t.roots.as_slice())
                    .unwrap_or_default();
                let forward_traces = issue_data
                    .traces
                    .iter()
                    .find(|t| t.name == "forward")
                    .map(|t| t.roots.as_slice())
                    .unwrap_or_default();

                let filename = issue_data
                    .location
                    .filename
                    .clone()
                    .filter(|f| f != "*")
                    .or(issue_data.location.path.clone());

                if let Some(trace) = forward_traces.first() {
                    traces.extend(self.find_traces(
                        trace,
                        TraceDirection::Forward,
                        filename.clone(),
                        &[],
                    ));
                }

                traces.push(TraceEntry {
                    status: TraceEntryStatus::Present,
                    callable: issue_data.callable.clone(),
                    port: "root".to_string(),
                    location: issue_data.location.clone(),
                });

                if let Some(trace) = backward_traces.first() {
                    traces.extend(
                        self.find_traces(trace, TraceDirection::Backward, filename.clone(), &[])
                            .into_iter()
                            .rev(),
                    );
                }

                ProcessedIssue {
                    location: issue_data.location.clone(),
                    trace: traces,
                    label: IssueLabel::default(),
                    getattr_count,
                }
            })
            .collect();

        ProcessedResults {
            issues,
            warnings: vec![],
            resolved_dependencies: vec![],
            raw_issue_count: self.raw_issue_count,
        }
    }

    fn find_traces(
        &self,
        trace: &TraceFragment,
        dir: TraceDirection,
        filename: Option<String>,
        visited: &[(String, String)],
    ) -> Vec<TraceEntry> {
        let (callable, port, location) = match trace {
            TraceFragment::Origin(taint_root_origin) => {
                let Some(leaf) = taint_root_origin
                    .kinds
                    .iter()
                    .flat_map(|k| &k.leaves)
                    .next()
                else {
                    return vec![];
                };

                (&leaf.name, &leaf.port, &taint_root_origin.origin)
            }
            TraceFragment::Call(taint_root_call) => {
                let call = &taint_root_call.call;
                let Some(callable) = call.resolves_to.first() else {
                    return vec![];
                };
                (callable, &call.port, &call.position)
            }
            TraceFragment::Declaration(_) => return vec![],
        };

        let location = filename
            .map(|f| location.with_filename(f))
            .unwrap_or_else(|| location.clone());

        if visited.iter().any(|(c, p)| c == callable && p == port) {
            return vec![TraceEntry {
                status: TraceEntryStatus::Recursive,
                callable: callable.clone(),
                port: port.clone(),
                location,
            }];
        }

        let Some((new_filename, fragment)) = self.find_model(callable, port, dir) else {
            return vec![TraceEntry {
                status: TraceEntryStatus::Missing,
                callable: callable.clone(),
                port: port.clone(),
                location,
            }];
        };

        let mut new_visited = visited.to_vec();
        new_visited.push((callable.clone(), port.clone()));

        let mut res = self.find_traces(fragment, dir, new_filename, &new_visited);
        res.push(TraceEntry {
            status: TraceEntryStatus::Present,
            callable: callable.clone(),
            port: port.clone(),
            location,
        });

        res
    }

    fn find_model<'a>(
        &'a self,
        callable: &String,
        port: &String,
        dir: TraceDirection,
    ) -> Option<(Option<String>, &'a TraceFragment)> {
        let model = self
            .models
            .binary_search_by_key(callable, |m| m.callable.clone())
            .ok()
            .map(|i| &self.models[i])?;
        let traces = match dir {
            TraceDirection::Forward => &model.sources,
            TraceDirection::Backward => &model.sinks,
        };
        let fragment = traces
            .iter()
            .find(|t| &t.port == port)
            .and_then(|trace| trace.taint.first())?;

        let filename = model
            .filename
            .clone()
            .filter(|f| f != "*")
            .or(model.path.clone());

        Some((filename, fragment))
    }
}

#[derive(Debug)]
pub struct ProcessedResults {
    pub issues: Vec<ProcessedIssue>,
    pub warnings: Vec<String>,
    pub resolved_dependencies: Vec<PipPackage>,
    pub raw_issue_count: usize,
}

impl ProcessedResults {
    pub fn summarise(&self) -> Result<String> {
        let mut s = String::new();

        let issues_one_attr = self
            .issues
            .iter()
            .filter(|issue| issue.getattr_count == GetAttrCount::One)
            .collect::<Vec<_>>();
        let issues_two_plus_attr = self
            .issues
            .iter()
            .filter(|issue| issue.getattr_count == GetAttrCount::TwoPlus)
            .collect::<Vec<_>>();
        let issues_conditional_attr = self
            .issues
            .iter()
            .filter(|issue| issue.getattr_count == GetAttrCount::Conditional)
            .collect::<Vec<_>>();

        writeln!(s, "Issues with one getattr: {}", issues_one_attr.len())?;
        for issue in issues_one_attr {
            writeln!(
                s,
                "- at {}, line {}",
                issue.location.filename.as_deref().unwrap_or("<unknown>"),
                issue.location.line
            )?;
        }
        writeln!(
            s,
            "Issues with two+ getattr: {}",
            issues_two_plus_attr.len()
        )?;
        for issue in issues_two_plus_attr {
            writeln!(
                s,
                "- at {}, line {}",
                issue.location.filename.as_deref().unwrap_or("<unknown>"),
                issue.location.line
            )?;
        }
        writeln!(
            s,
            "Issues with a conditional number of getattr: {}",
            issues_conditional_attr.len()
        )?;
        for issue in issues_conditional_attr {
            writeln!(
                s,
                "- at {}, line {}",
                issue.location.filename.as_deref().unwrap_or("<unknown>"),
                issue.location.line
            )?;
        }
        writeln!(s, "Total issues: {}", self.issues.len())?;

        Ok(s)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProcessedIssue {
    pub location: SpanLocation,
    pub trace: Vec<TraceEntry>,
    #[serde(default)]
    pub label: IssueLabel,
    pub getattr_count: GetAttrCount,
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum IssueLabel {
    #[default]
    Unlabeled,
    Vulnerable {
        #[serde(default)]
        features: Vec<VulnerableFeature>,
    },
    // not-vulnerable:
    NotVulnerable {
        #[serde(default)]
        reasons: Vec<NotVulnerableReason>,
    },
}

impl Display for IssueLabel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            IssueLabel::Unlabeled => "Unlabeled (skip)".fmt(f),
            IssueLabel::Vulnerable { .. } => "Vulnerable".fmt(f),
            IssueLabel::NotVulnerable { .. } => "Not Vulnerable (false positive)".fmt(f),
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum VulnerableFeature {
    /// It is possible to access the values of a dictionary
    DictAccess,
    /// It is possible to access the values of a list or tuple (e.g., numeric keys only)
    ListTupleAccess,
    /// Setting the value is done (conditionally) using __setitem__
    SupportsSetItem,
    /// The function somehow makes it easier to access a gadget (e.g., it accesses __globals__ for
    /// us)
    AdditionalBenefits,
    /// The value being set is not controlled by function inputs
    ValueNotControlled,
    /// The final (or intermediate) attributes need to exist already
    NeedsExisting,
    /// The target or intermediate classes have constraints (e.g., a certain field needs to exist)
    AdditionalConstraints,
}

impl Display for VulnerableFeature {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            VulnerableFeature::DictAccess => {
                "Dict Access: accesses the values of a dictionary".fmt(f)
            }
            VulnerableFeature::ListTupleAccess => {
                "List/Tuple Access: accesses the values of a list/tuple (e.g., numeric keys only)"
                    .fmt(f)
            }
            VulnerableFeature::SupportsSetItem => {
                "Supports __setitem__: sets the value using __setitem__".fmt(f)
            }
            VulnerableFeature::AdditionalBenefits => {
                "Additional Benefits: somehow makes it easier to access a gadget".fmt(f)
            }
            VulnerableFeature::ValueNotControlled => {
                "Value Not Controlled: value being set is not controlled by function inputs".fmt(f)
            }
            VulnerableFeature::NeedsExisting => {
                "Needs Existing: the attributes need to exist already".fmt(f)
            }
            VulnerableFeature::AdditionalConstraints => {
                "Additional Constraints: e.g., a certain field of target class needs to exist"
                    .fmt(f)
            }
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "kind")]
pub enum NotVulnerableReason {
    /// The object passed to setattr is no longer the result value of getattr
    ModifiedReference,
    /// The code does not recurse/iterate the calls to getattr
    NonRecursive,
    /// There is a filter in place to prevent attributes like __globals__
    Filtered,
    /// The attributes are not controlled by function inputs/variables (e.g., they are static
    /// strings, f-strings or concatenation of strings)
    NotControlled,
    /// Only a predefined list of attributes is allowed to flow into getattr and/or setattr.
    AttrAllowList,
    Other {
        notes: String,
    },
}

impl Display for NotVulnerableReason {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            NotVulnerableReason::ModifiedReference => {
                "Modified Reference: the object passed to setattr is no longer the result value of getattr".fmt(f)
            }
            NotVulnerableReason::NonRecursive => {
                "Non Recursive: the code does not recurse/iterate the calls to getattr".fmt(f)
            }
            NotVulnerableReason::Filtered => {
                "Filtered: there is a filter in place to prevent attributes like __globals__".fmt(f)
            }
            NotVulnerableReason::NotControlled => {
                "Not Controlled: the attributes are not controlled by function inputs/variables".fmt(f)
            }
            NotVulnerableReason::AttrAllowList => {
                "Attr Allow List: only a predefined list of attributes is allowed".fmt(f)
            }
            NotVulnerableReason::Other { .. } => "Other (requires comment)".fmt(f),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum GetAttrCount {
    One,
    TwoPlus,
    /// Possibly this is a loop or recursive function
    Conditional,
}

impl GetAttrCount {
    /// Determine how many times `getattr` is called before reaching the sink.
    /// This is useful to know whether the exploit is viable or not, since usually at least two
    /// calls to `getattr` are required to have a meaningful exploit.
    ///
    /// This works by checking if the source passes through another `getattr` (via the feature
    /// `customgetattr`). If it always passes through it (`always-via`), then we always get at
    /// least two calls to `getattr`. Otherwise, the number of calls to `getattr` could depend on a
    /// loop or recursive function.
    pub fn from_issue_data(issue_data: &TaintIssueData) -> Self {
        for feature in &issue_data.features {
            if feature.always_via == Some("customgetattr".to_string()) {
                return Self::TwoPlus;
            }
            if feature.via == Some("customgetattr".to_string()) {
                return Self::Conditional;
            }
        }

        Self::One
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TraceEntry {
    pub status: TraceEntryStatus,
    pub callable: String,
    pub port: String,
    pub location: SpanLocation,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TraceEntryStatus {
    Missing,
    Recursive,
    Present,
}

#[derive(Debug, Clone, Copy)]
enum TraceDirection {
    Forward,
    Backward,
}
