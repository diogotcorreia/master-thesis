use thiserror::Error;

#[derive(Error, Debug)]
pub enum ToolError {
    #[error("error executing pyre (stdout: {stdout}, stderr: {stderr})")]
    PyreError { stdout: String, stderr: String },
    #[error("error executing uv (stdout: {stdout}, stderr: {stderr})")]
    UvError { stdout: String, stderr: String },
}
