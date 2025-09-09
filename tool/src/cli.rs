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
    /// A path to the work directory to use, for storing files during the analysis and
    /// also final reports, when applicable.
    pub workdir: Option<PathBuf>,

    #[arg(long, env)]
    /// Whether to keep the work directory after exiting, instead of deleting it.
    /// This is implicitly true if the --workdir option is given.
    pub keep_workdir: bool,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Run analysis on a Python program and try to find class pollution
    Analyse(AnalyseArgs),
    /// Run an end-to-end pipeline, analysing the projects declared in the given dataset
    E2E(E2EArgs),
    /// Parse results from a pysa run and summarise them
    Results(ResultsArgs),
    /// Parse reports from a previous e2e run, show issues, and ask for appropriate labels
    Label(LabelArgs),
    /// Parse reports from a previous e2e run, and compile it into a JSON file that be used for charts
    Summary(SummaryArgs),
}

#[derive(Args)]
pub struct AnalyseArgs {
    #[arg(long)]
    /// Whether to install dependencies before performing the analysis
    pub use_deps: bool,
    #[arg(long, requires = "use_deps")]
    /// Whether to only find vulnerable functions that can be reached from user-controlled code
    /// (requires --use-deps)
    pub require_user_controlled: bool,
    #[arg()]
    /// Path to the project to analyse
    pub dir: PathBuf,
}

#[derive(Args)]
pub struct E2EArgs {
    #[arg(long)]
    /// Whether to install dependencies before performing the analysis
    pub use_deps: bool,
    #[arg(long, requires = "use_deps")]
    /// Whether to only find vulnerable functions that can be reached from user-controlled code
    /// (requires --use-deps)
    pub require_user_controlled: bool,
    #[arg()]
    /// Path to a TOML file containing dataset information
    pub dataset: PathBuf,
}

#[derive(Args)]
pub struct ResultsArgs {
    #[arg()]
    /// Path to the pysa-results directory
    pub results_dir: PathBuf,
}

#[derive(Args)]
pub struct LabelArgs {
    #[arg(long)]
    /// Path to a TOML file containing dataset information.
    /// When used, only reports for repos in the dataset are considered.
    pub dataset: Option<PathBuf>,
}

#[derive(Args)]
pub struct SummaryArgs {
    #[arg(long)]
    /// Path to a TOML file containing dataset information.
    /// When used, only reports for repos in the dataset are considered.
    pub dataset: Option<PathBuf>,
}
