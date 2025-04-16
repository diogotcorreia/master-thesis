use thiserror::Error;

#[derive(Error, Debug)]
pub enum ToolError {
    #[error("error executing pyre (stdout: {stdout}, stderr: {stderr})")]
    PyreError { stdout: String, stderr: String },
    #[error("cannot parse results due to version mismatch (expected {expected}, but got {got})")]
    PyreResultVersionMismatch { got: u32, expected: u32 },
    #[error("error executing uv (stdout: {stdout}, stderr: {stderr})")]
    UvError { stdout: String, stderr: String },
}
