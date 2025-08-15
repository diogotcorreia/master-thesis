use std::{
    fs::{self, File},
    io,
    os::unix::process::CommandExt,
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result};
use results::{ProcessedResults, UnprocessedResults};
use signal_child::signal;
use tracing::{debug, info, warn};
use wait_timeout::ChildExt;

use crate::{
    errors::{PipelineResult, PipelineStage, ToolError, WithPipelineStage},
    pyre::{
        config::{
            PyreConfiguration, SitePackageSearchStrategy, TaintConfig, TaintEntry, TaintOptions,
            TaintRule,
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
    pub resolve_dependencies: bool,
    pub resolve_dependencies_opts: &'a ResolveDependenciesOpts,
}

impl AnalyseOptions<'_> {
    #[tracing::instrument(skip(self))]
    pub fn run_analysis(&self) -> PipelineResult<ProcessedResults> {
        info!("Started analysis of {:?}", self.project_dir);

        let mut warnings = vec![];

        let lockfile = if self.resolve_dependencies {
            if let Some((lockfile_path, lockfile)) = compile_pylock(
                self.project_dir,
                &self.project_dir.join(SRC_DIR),
                self.resolve_dependencies_opts,
            )
            .context("failed to resolve dependencies")
            .with_stage(PipelineStage::ResolvingDependencies)?
            {
                self.install_dependencies(&lockfile_path)
                    .with_stage(PipelineStage::InstallingDependencies)?;
                if lockfile.packages.is_empty() {
                    warn!("No dependencies detected");
                    warnings.push("No dependencies detected".to_string());
                }
                lockfile
            } else {
                warn!("No dependency files detected");
                warnings.push("No dependency files detected".to_string());
                PyLock::default()
            }
        } else {
            PyLock::default()
        };

        self.setup_pyre_files()
            .with_stage(PipelineStage::PyreSetup)?;
        let results_dir = self
            .run_pysa()
            .context("failed to execute pysa")
            .with_stage(PipelineStage::Analysis)?;
        let mut results = self
            .get_pyre_results(&results_dir)
            .with_stage(PipelineStage::Processing)?;
        info!(
            "Results:\n{}",
            results.summarise().with_stage(PipelineStage::Processing)?
        );
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

    #[tracing::instrument(skip(self))]
    fn setup_pyre_files(&self) -> Result<()> {
        let config = PyreConfiguration {
            site_package_search_strategy: SitePackageSearchStrategy::All,
            source_directories: vec![format!("./{SRC_DIR}")],
            taint_models_path: vec![".".to_string()],
            site_roots: vec![format!("./{DEPS_DIR}")],
        };

        let taint_config = TaintConfig {
            sources: vec![TaintEntry {
                name: "CustomGetAttr".to_string(),
            }],
            sinks: vec![TaintEntry {
                name: "CustomSetAttr".to_string(),
            }],
            features: vec![TaintEntry {
                name: "customgetattr".to_string(),
            }],
            rules: vec![TaintRule {
                name: "class-pollution".to_string(),
                code: 9901,
                sources: vec!["CustomGetAttr".to_string()],
                sinks: vec!["CustomSetAttr".to_string()],
                message_format: "There might be class pollution here".to_string(),
            }],
            combined_source_rules: vec![],
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
        write_taint_models(&sources_sinks_path)?;

        debug!("setup pyre/pysa configuration files");

        Ok(())
    }

    #[tracing::instrument(skip(self))]
    fn run_pysa(&self) -> Result<PathBuf> {
        let results_path = self.project_dir.join(PYSA_RESULTS_DIR);

        let mut child = Command::new(self.pyre_path)
            .arg("--log-level")
            .arg("WARNING")
            .arg("analyze")
            .arg("--rule")
            .arg("9901")
            // .arg("--infer-self-tito")
            .arg("--save-results-to")
            .arg(&results_path)
            .current_dir(self.project_dir)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .process_group(0)
            .spawn()?;

        let timeout = Duration::from_secs(60 * 60 * 2); // 2 hours
        match child.wait_timeout(timeout)? {
            Some(status) => {
                if status.success() {
                    debug!("ran pysa and saved results to {results_path:?}");
                    Ok(results_path)
                } else {
                    let output = child.wait_with_output()?;
                    Err(ToolError::PyreError {
                        stdout: String::from_utf8(output.stdout)?,
                        stderr: String::from_utf8(output.stderr)?,
                    }
                    .into())
                }
            }
            None => {
                // kill the entire process group, so that children are killed as well
                signal(-(child.id() as i32), signal::Signal::SIGKILL)?;
                Err(ToolError::PyreTimeout.into())
            }
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
