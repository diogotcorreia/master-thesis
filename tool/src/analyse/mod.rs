use std::{
    fs::{self, DirEntry, File},
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
    python::PyLock,
};

const SRC_DIR: &str = "src";
const PYSA_RESULTS_DIR: &str = "pysa-results";
const LOCKFILE_NAME: &str = "pylock.toml";
const DEPS_DIR: &str = "deps";

pub mod results;

#[derive(Debug)]
pub struct AnalyseOptions<'a> {
    pub project_dir: &'a Path,
    pub pyre_path: &'a Path,
}

impl AnalyseOptions<'_> {
    #[tracing::instrument(skip(self))]
    pub fn run_analysis(&self) -> Result<ProcessedResults> {
        info!("Started analysis of {:?}", self.project_dir);

        let mut warnings = vec![];

        let dependency_files = self.find_dependency_files()?;
        let lockfile = if !dependency_files.is_empty() {
            let (lockfile_path, lockfile) = self.resolve_dependencies(&dependency_files)?;
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
    /// Finds files that contain dependency information in the project's src directory.
    /// Candidate files are pyproject.toml, requirements*.txt, setup.py and setup.cfg.
    /// Only files at the root of the project are considered.
    fn find_dependency_files(&self) -> Result<Vec<PathBuf>> {
        fn is_dep_file(entry: &DirEntry) -> bool {
            // only files are considered, not directories
            if !entry.file_type().map(|ft| ft.is_file()).unwrap_or(false) {
                return false;
            }
            if let Ok(name) = entry.file_name().into_string() {
                name == "pyproject.toml"
                    || name == "setup.py"
                    || name == "setup.cfg"
                    || (name.starts_with("requirements") && name.ends_with(".txt"))
            } else {
                false
            }
        }

        Ok(self
            .project_dir
            .join(SRC_DIR)
            .read_dir()?
            .filter_map(|entry| entry.ok().filter(is_dep_file).map(|entry| entry.path()))
            .collect())
    }

    #[tracing::instrument(skip(self))]
    fn resolve_dependencies(&self, dependency_files: &[PathBuf]) -> Result<(PathBuf, PyLock)> {
        let supports_extras = dependency_files
            .iter()
            .map(|p| {
                p.file_name()
                    .unwrap_or_default()
                    .to_str()
                    .unwrap_or_default()
            })
            .any(|x| x == "pyproject.toml" || x == "setup.py" || x == "setup.cfg");

        let lockfile_path = self.project_dir.join(LOCKFILE_NAME);
        let output = Command::new("uv")
            .arg("pip")
            .arg("compile")
            .args(if supports_extras {
                ["--all-extras"].as_slice()
            } else {
                &[]
            })
            .arg("--generate-hashes")
            .arg("--universal")
            .arg("--output-file")
            .arg(&lockfile_path)
            .arg("--")
            .args(dependency_files)
            .current_dir(self.project_dir.join(SRC_DIR))
            .output()
            .context("failed to resolve dependencies")?;

        if output.status.success() {
            debug!("ran uv pip compile and saved results to {lockfile_path:?}");
            let lockfile_content =
                fs::read_to_string(&lockfile_path).context("failed to read resulting lockfile")?;
            let lockfile =
                toml::from_str(&lockfile_content).context("failed to parse resulting lockfile")?;
            Ok((lockfile_path, lockfile))
        } else {
            Err(ToolError::UvError {
                stdout: String::from_utf8(output.stdout)?,
                stderr: String::from_utf8(output.stderr)?,
            }
            .into())
        }
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
        let taint_config_path = self.project_dir.join("taint.config");
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
