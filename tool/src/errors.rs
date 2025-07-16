use anyhow::Error;
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ToolError {
    #[error("error executing pyre (stdout: {stdout}, stderr: {stderr})")]
    PyreError { stdout: String, stderr: String },
    #[error("cannot parse results due to version mismatch (expected {expected}, but got {got})")]
    PyreResultVersionMismatch { got: u32, expected: u32 },
    #[error("reached timeout while executing pyre")]
    PyreTimeout,
    #[error("error executing uv (stdout: {stdout}, stderr: {stderr})")]
    UvError { stdout: String, stderr: String },
}

pub type PipelineResult<T> = Result<T, PipelineError>;

pub struct PipelineError {
    pub stage: PipelineStage,
    pub error: Error,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum PipelineStage {
    Setup,
    ResolvingDependencies,
    InstallingDependencies,
    PyreSetup,
    Analysis,
    Processing,
    Cleanup,
}

pub trait WithPipelineStage<T> {
    fn with_stage(self, stage: PipelineStage) -> Result<T, PipelineError>;
}

impl<T, E> WithPipelineStage<T> for Result<T, E>
where
    E: Into<Error>,
{
    fn with_stage(self, stage: PipelineStage) -> Result<T, PipelineError> {
        self.map_err(|e| PipelineError {
            stage,
            error: e.into(),
        })
    }
}
