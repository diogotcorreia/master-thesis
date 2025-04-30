use std::{
    path::{Path, PathBuf},
    str::FromStr,
};

use anyhow::{Context, Result};
use clap::Parser;
use class_pollution_detection::{
    analyse::{setup_project_from_external_src, AnalyseOptions},
    cli::{Cli, Commands},
};
use tempdir::TempDir;
use tracing::debug;

fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    let workdir = TempDir::new("class-pollution-detection")
        .context("failed to create work dir in temporary directory")?;
    debug!("created work dir at {:?}", workdir.path());

    // save result for later so that we can still handle logic of workdir deletion
    let result = handle_command(workdir.path(), &cli);

    if cli.keep_workdir {
        // avoid deleting workdir on drop
        workdir.into_path();
        debug!("keeping work dir");
    } else {
        workdir
            .close()
            .context("failed to delete work dir in temporary directory")?;
        debug!("deleted work dir");
    }

    result
}

fn handle_command(workdir: &Path, cli: &Cli) -> Result<()> {
    match &cli.command {
        Commands::Analyse(analyse_args) => {
            let project_dir = setup_project_from_external_src(workdir, &analyse_args.dir)?;
            let options = AnalyseOptions {
                work_dir: workdir.to_path_buf(),
                project_dir,
                pyre_path: cli.pyre_path.clone().unwrap_or(PathBuf::from_str("pyre")?),
                pyre_lib_path: cli.pyre_lib_path.clone(),
            };
            options.run_analysis()?;
        }
    }

    Ok(())
}
