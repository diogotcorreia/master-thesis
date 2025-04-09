use std::{path::PathBuf, str::FromStr};

use anyhow::{Context, Result};
use clap::Parser;
use class_pollution_detection::{analyse::AnalyseOptions, cli::{Cli, Commands}};
use tempdir::TempDir;
use tracing::debug;

fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    let workdir = TempDir::new("class-pollution-detection")
        .context("failed to create work dir in temporary directory")?;
    debug!("created work dir at {workdir:?}");

    match cli.command {
        Commands::Analyse(analyse_args) => {
            let options = AnalyseOptions {
                work_dir: workdir.path().to_path_buf(),
                project_dir: analyse_args.dir,
                pyre_path: cli.pyre_path.unwrap_or(PathBuf::from_str("pyre")?),
            };
            options.run_analysis()?;
        }
    }

    workdir
        .close()
        .context("failed to delete work dir in temporary directory")?;
    debug!("deleted work dir");
    Ok(())
}
