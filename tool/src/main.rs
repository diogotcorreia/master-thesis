use std::{
    fs,
    path::{Path, PathBuf},
    str::FromStr,
};

use anyhow::{Context, Result};
use clap::Parser;
use class_pollution_detection::{
    analyse::{results::UnprocessedResults, setup_project_from_external_src, AnalyseOptions},
    cli::{Cli, Commands},
    e2e::{config::DatasetConfig, pipeline::Pipeline},
    python::deps::ResolveDependenciesOpts,
    Workdir,
};
use tracing::info;

fn main() -> Result<()> {
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    let workdir = Workdir::from_cli(&cli)?;

    // save result for later so that we can still handle logic of workdir deletion
    let result = handle_command(workdir.path(), &cli);

    workdir.close()?;

    result
}

fn handle_command(workdir: &Path, cli: &Cli) -> Result<()> {
    let pyre_path = cli.pyre_path.clone().unwrap_or(PathBuf::from_str("pyre")?);
    match &cli.command {
        Commands::Analyse(analyse_args) => {
            let project_dir = setup_project_from_external_src(workdir, &analyse_args.dir)?;
            let options = AnalyseOptions {
                project_dir: &project_dir,
                pyre_path: &pyre_path,
                resolve_dependencies_opts: &ResolveDependenciesOpts::default(),
            };
            options.run_analysis().map_err(|e| e.error)?;
        }
        Commands::E2E(e2e_args) => {
            let dataset_content =
                fs::read_to_string(&e2e_args.dataset).context("failed to read dataset config")?;
            let dataset_config: DatasetConfig =
                toml::from_str(&dataset_content).context("failed to parse dataset config")?;

            let pipeline = Pipeline::new(workdir, &dataset_config, &pyre_path);
            pipeline.run()?;
        }
        Commands::Results(results_args) => {
            let results = UnprocessedResults::from_results_dir(&results_args.results_dir)
                .context("failed to parse results")?;

            let results = results.process();

            info!("Summary:\n{}", results.summarise()?);
        }
    }

    Ok(())
}
