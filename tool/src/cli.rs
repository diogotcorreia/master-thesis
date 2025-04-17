use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};

#[derive(Parser)]
#[command(version, about)]
/// Find class pollution in Python programs
pub struct Cli {
    #[arg(long, env)]
    /// Path to the pyre (Python) program.
    /// If not provided, tries to find it in PATH.
    pub pyre_path: Option<PathBuf>,

    #[arg(long, env)]
    /// Whether to keep the work directory after exiting, instead of deleting it.
    pub keep_workdir: bool,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Run analysis on a Python program and try to find class pollution
    Analyse(AnalyseArgs),
}

#[derive(Args)]
pub struct AnalyseArgs {
    #[arg()]
    /// Path to the project to analyse
    pub dir: PathBuf,
}
