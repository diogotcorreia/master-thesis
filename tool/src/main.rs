use std::{
    path::{Path, PathBuf},
    str::FromStr,
};

use anyhow::{Context, Result};
use clap::Parser;
use class_pollution_detection::{
    analyse::{results::UnprocessedResults, setup_project_from_external_src, AnalyseOptions},
    cli::{Cli, Commands},
    e2e::{config::DatasetConfig, labeling::Labeling, pipeline::Pipeline, summary::Summary},
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
                resolve_dependencies: analyse_args.use_deps,
                resolve_dependencies_opts: &ResolveDependenciesOpts::default(),
            };
            options.run_analysis().map_err(|e| e.error)?;
        }
        Commands::E2E(e2e_args) => {
            let dataset_config = DatasetConfig::read(&e2e_args.dataset)?;

            let pipeline = Pipeline::new(workdir, &dataset_config, &pyre_path, e2e_args.use_deps);
            pipeline.run()?;
        }
        Commands::Results(results_args) => {
            let results = UnprocessedResults::from_results_dir(&results_args.results_dir)
                .context("failed to parse results")?;

            let results = results.process();

            info!("Summary:\n{}", results.summarise()?);
        }
        Commands::Label(label_args) => {
            let dataset_config = label_args
                .dataset
                .as_ref()
                .map(|path| DatasetConfig::read(path))
                .transpose()?;

            let labeling = Labeling::new(workdir, dataset_config.as_ref());
            labeling.prompt_unlabeled()?;
        }
        Commands::Temp(label_args) => {
            let dataset_config = label_args
                .dataset
                .as_ref()
                .map(|path| DatasetConfig::read(path))
                .transpose()?;

            let labeling = Labeling::new(workdir, dataset_config.as_ref());
            labeling.prompt_unlabeled()?;
        }
        Commands::Summary(summary_args) => {
            let dataset_config = summary_args
                .dataset
                .as_ref()
                .map(|path| DatasetConfig::read(path))
                .transpose()?;

            let summary = Summary::new(workdir, dataset_config.as_ref());
            summary.compile_summary_json()?;
        }
    }

    Ok(())
}
