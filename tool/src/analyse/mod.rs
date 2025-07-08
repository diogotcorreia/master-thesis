use std::{
    fs::{self, File},
    io,
    path::{Path, PathBuf},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result};
use results::{ProcessedResults, UnprocessedResults};
use tracing::{debug, info, warn};

use crate::{
    errors::ToolError,
    pyre::{
        config::{
            PyreConfiguration, SitePackageSearchStrategy, TaintCombinedSourceRule, TaintConfig,
            TaintEntry, TaintOptions, TaintPartialRule,
        },
        models::write_taint_models,
    },
    python::{
        deps::{compile_pylock, ResolveDependenciesOpts},
        PyLock,
    },
};

const SRC_DIR: &str = "src";
const PYSA_RESULTS_DIR: &str = "pysa-results";
const DEPS_DIR: &str = "deps";

pub mod results;

#[derive(Debug)]
pub struct AnalyseOptions<'a> {
    pub project_dir: &'a Path,
    pub pyre_path: &'a Path,
    pub resolve_dependencies_opts: &'a ResolveDependenciesOpts,
}

impl AnalyseOptions<'_> {
    #[tracing::instrument(skip(self))]
    pub fn run_analysis(&self) -> Result<ProcessedResults> {
        info!("Started analysis of {:?}", self.project_dir);

        let mut warnings = vec![];

        let lockfile = if let Some((lockfile_path, lockfile)) = compile_pylock(
            self.project_dir,
            &self.project_dir.join(SRC_DIR),
            self.resolve_dependencies_opts,
        )
        .context("failed to resolve dependencies")?
        {
            self.install_dependencies(&lockfile_path)?;
            if lockfile.packages.is_empty() {
                warn!("No dependencies detected");
                warnings.push("No dependencies detected".to_string());
            }
            lockfile
        } else {
            warn!("No dependency files detected");
            warnings.push("No dependency files detected".to_string());
            PyLock::default()
        };

        self.setup_pyre_files(&lockfile)?;
        let results_dir = self.run_pysa()?;
        let mut results = self.get_pyre_results(&results_dir)?;
        info!("Results:\n{}", results.summarise()?);
        results.warnings = warnings;
        results.resolved_dependencies = lockfile.packages;
        Ok(results)
    }

    #[tracing::instrument(skip(self))]
    fn install_dependencies(&self, lockfile_path: &Path) -> Result<()> {
        let output = Command::new("uv")
            .arg("pip")
            .arg("install")
            .arg("--target")
            .arg(self.project_dir.join(DEPS_DIR))
            .arg("--requirements")
            .arg(lockfile_path)
            .current_dir(self.project_dir.join(SRC_DIR))
            .output()
            .context("failed to install dependencies")?;

        if output.status.success() {
            debug!("ran uv pip install");
            Ok(())
        } else {
            Err(ToolError::UvError {
                stdout: String::from_utf8(output.stdout)?,
                stderr: String::from_utf8(output.stderr)?,
            }
            .into())
        }
    }

    #[tracing::instrument(skip(self, lockfile))]
    fn setup_pyre_files(&self, lockfile: &PyLock) -> Result<()> {
        let config = PyreConfiguration {
            site_package_search_strategy: SitePackageSearchStrategy::All,
            source_directories: vec![format!("./{SRC_DIR}")],
            taint_models_path: vec![".".to_string()],
            site_roots: vec![format!("./{DEPS_DIR}")],
        };

        let taint_config = TaintConfig {
            sources: vec![
                TaintEntry {
                    name: "CustomGetAttr".to_string(),
                },
                TaintEntry {
                    name: "UserControlled".to_string(),
                },
            ],
            sinks: vec![TaintEntry {
                name: "CustomSetAttr".to_string(),
            }],
            features: vec![TaintEntry {
                name: "customgetattr".to_string(),
            }],
            rules: vec![],
            combined_source_rules: vec![TaintCombinedSourceRule {
                name: "class-pollution".to_string(),
                code: 9901,
                rule: vec![
                    TaintPartialRule {
                        sources: vec!["CustomGetAttr".to_string()],
                        partial_sink: "CustomSetAttr".to_string(),
                    },
                    TaintPartialRule {
                        sources: vec!["UserControlled".to_string()],
                        partial_sink: "UserControlledSink".to_string(),
                    },
                ],
                message_format: "There might be class pollution here".to_string(),
            }],
            options: TaintOptions {
                maximum_overrides_to_analyze: 1,
                maximum_trace_length: 20,
            },
        };

        let config_path = self.project_dir.join(".pyre_configuration");
        let taint_config_path = self.project_dir.join("taint.pyre_config");
        let sources_sinks_path = self.project_dir.join("sources_sinks.pysa");

        serde_json::to_writer(File::create(config_path)?, &config)?;
        serde_json::to_writer(File::create(taint_config_path)?, &taint_config)?;
        write_taint_models(&sources_sinks_path, lockfile)?;

        debug!("setup pyre/pysa configuration files");

        Ok(())
    }

    #[tracing::instrument(skip(self))]
    fn run_pysa(&self) -> Result<PathBuf> {
        let results_path = self.project_dir.join(PYSA_RESULTS_DIR);

        let output = Command::new(self.pyre_path)
            .arg("--log-level")
            .arg("WARNING")
            .arg("analyze")
            .arg("--rule")
            .arg("9901")
            .arg("--infer-self-tito")
            .arg("--save-results-to")
            .arg(&results_path)
            .current_dir(self.project_dir)
            .output()
            .context("failed to execute pysa")?;

        if output.status.success() {
            debug!("ran pysa and saved results to {results_path:?}");
            Ok(results_path)
        } else {
            Err(ToolError::PyreError {
                stdout: String::from_utf8(output.stdout)?,
                stderr: String::from_utf8(output.stderr)?,
            }
            .into())
        }
    }

    #[tracing::instrument(skip(self))]
    fn get_pyre_results(&self, results_dir: &Path) -> Result<ProcessedResults> {
        Ok(UnprocessedResults::from_results_dir(results_dir)?.process())
    }
}

#[tracing::instrument]
/// Copy a project into the work directory.
/// A new directory is created inside the workdir with the name <project dir name>.<timestamp>,
/// and the contents of the given project_src are moved into a `src` directory inside this
/// newly-created directory.
/// The new project directory (not the inner src) is returned.
pub fn setup_project_from_external_src(work_dir: &Path, project_src: &Path) -> Result<PathBuf> {
    let destination_dir_name = {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_millis();

        let mut dir_name = project_src
            .file_name()
            .map(|s| s.to_os_string())
            .unwrap_or("unknown".into());
        dir_name.push(".");
        dir_name.push(now.to_string());
        dir_name
    };

    let project_dir = work_dir.join(destination_dir_name);
    let destination = project_dir.join(SRC_DIR);
    copy_dir_all(project_src, &destination).context("failed to copy project into work dir")?;

    debug!("copied project to {destination:?}");

    Ok(project_dir)
}

// stdlib does not have a function to copy directories :(
// https://stackoverflow.com/questions/26958489/how-to-copy-a-folder-recursively-in-rust
fn copy_dir_all(src: impl AsRef<Path>, dst: impl AsRef<Path>) -> io::Result<()> {
    fs::create_dir_all(&dst)?;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let ty = entry.file_type()?;
        if ty.is_dir() {
            copy_dir_all(entry.path(), dst.as_ref().join(entry.file_name()))?;
        } else {
            fs::copy(entry.path(), dst.as_ref().join(entry.file_name()))?;
        }
    }
    Ok(())
}
