use std::{
    fmt::Write,
    fs::File,
    io::{BufRead, BufReader},
    path::Path,
};

use anyhow::Result;
use serde::{Deserialize, Serialize};

use crate::{
    errors::ToolError,
    pyre::results::{TaintIssueData, TaintOutput, TaintOutputHeader},
};

const PYSA_TAINT_OUTPUT_NAME: &str = "taint-output.json";
const PYSA_TAINT_OUTPUT_SUPPORTED_VERSION: u32 = 3;

#[derive(Debug)]
pub struct UnprocessedResults {
    pub issues: Vec<TaintIssueData>,
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

        let issues = serde_json::Deserializer::from_reader(reader)
            .into_iter()
            .filter_map(|r| {
                r.map(|out: TaintOutput| match out {
                    TaintOutput::Issue(issue_data) => Some(issue_data),
                    _ => None,
                })
                .map_err(|r| r.into())
                .transpose()
            })
            .collect::<Result<Vec<_>>>()?;

        Ok(UnprocessedResults { issues })
    }

    pub fn process(self) -> ProcessedResults {
        let issues = self
            .issues
            .into_iter()
            .map(|issue_data| {
                let getattr_count = GetAttrCount::from_issue_data(&issue_data);

                ProcessedIssues {
                    raw_data: issue_data,
                    getattr_count,
                }
            })
            .collect();

        ProcessedResults { issues }
    }
}

#[derive(Debug)]
pub struct ProcessedResults {
    pub issues: Vec<ProcessedIssues>,
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
                issue
                    .raw_data
                    .location
                    .filename
                    .as_deref()
                    .unwrap_or("<unknown>"),
                issue.raw_data.location.line
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
                issue
                    .raw_data
                    .location
                    .filename
                    .as_deref()
                    .unwrap_or("<unknown>"),
                issue.raw_data.location.line
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
                issue
                    .raw_data
                    .location
                    .filename
                    .as_deref()
                    .unwrap_or("<unknown>"),
                issue.raw_data.location.line
            )?;
        }
        writeln!(s, "Total issues: {}", self.issues.len())?;

        Ok(s)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ProcessedIssues {
    pub raw_data: TaintIssueData,
    pub getattr_count: GetAttrCount,
}

#[derive(Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum GetAttrCount {
    None, // should not happen?
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
        let Some(forward_trace) = issue_data
            .traces
            .iter()
            .find(|trace| trace.name == "forward")
        else {
            return Self::None;
        };

        let all_features = forward_trace.roots.iter().flat_map(|root| {
            root.local_features()
                .iter()
                .chain(root.kinds().iter().flat_map(|kind| kind.features.iter()))
        });

        for feature in all_features {
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
