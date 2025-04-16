use std::{
    fs::{self, DirEntry, File},
    io::{self, BufRead, BufReader},
    path::{Path, PathBuf},
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result};
use tracing::{debug, info};

use crate::{
    errors::ToolError,
    pyre::{
        config::{
            PyreConfiguration, SitePackageSearchStrategy, TaintConfig, TaintEntry, TaintOptions,
            TaintRule,
        },
        results::{TaintOutput, TaintOutputHeader},
    },
};

const SRC_DIR: &str = "src";
const PYSA_RESULTS_DIR: &str = "pysa-results";
const PYSA_TAINT_OUTPUT_NAME: &str = "taint-output.json";
const LOCKFILE_NAME: &str = "requirements.lock.txt";
const DEPS_DIR: &str = "deps";

const PYSA_TAINT_OUTPUT_SUPPORTED_VERSION: u32 = 3;

#[derive(Debug)]
pub struct AnalyseOptions {
    pub work_dir: PathBuf,
    pub project_dir: PathBuf,
    pub pyre_path: PathBuf,
}

impl AnalyseOptions {
    #[tracing::instrument(skip(self))]
    pub fn run_analysis(&self) -> Result<()> {
        info!("Started analysis of {:?}", self.project_dir);

        let dependency_files = self.find_dependency_files()?;
        let lockfile = self.resolve_dependencies(&dependency_files)?;
        self.install_dependencies(&lockfile)?;

        self.setup_pyre_files()?;
        let results_dir = self.run_pysa()?;
        let results = self.get_pyre_results(&results_dir)?;
        debug!("Results: {results:#?}");
        Ok(())
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
    fn resolve_dependencies(&self, dependency_files: &[PathBuf]) -> Result<PathBuf> {
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
            Ok(lockfile_path)
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

    #[tracing::instrument(skip(self))]
    fn setup_pyre_files(&self) -> Result<()> {
        let config = PyreConfiguration {
            site_package_search_strategy: SitePackageSearchStrategy::Pep561,
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
            options: TaintOptions {
                maximum_overrides_to_analyze: 1,
                maximum_trace_length: 20,
            },
        };

        let sources_sinks = r#"
@SkipObscure
def getattr(
    __o: TaintInTaintOut[Via[customgetattr]],
    __name,
    __default: TaintInTaintOut[LocalReturn],
) -> TaintSource[CustomGetAttr, ViaValueOf[__name, WithTag["get-name"]]]: ...

@SkipObscure
def setattr(
    __o: TaintSink[CustomSetAttr, ViaValueOf[__name, WithTag["set-name"]], ViaValueOf[__value, WithTag["set-value"]]],
    __name,
    __value,
): ...
"#;

        let config_path = self.project_dir.join(".pyre_configuration");
        let taint_config_path = self.project_dir.join("taint.config");
        let sources_sinks_path = self.project_dir.join("sources_sinks.pysa");

        serde_json::to_writer(File::create(config_path)?, &config)?;
        serde_json::to_writer(File::create(taint_config_path)?, &taint_config)?;
        std::fs::write(sources_sinks_path, sources_sinks)?;

        debug!("setup pyre/pysa configuration files");

        Ok(())
    }

    #[tracing::instrument(skip(self))]
    fn run_pysa(&self) -> Result<PathBuf> {
        let results_path = self.project_dir.join(PYSA_RESULTS_DIR);

        let output = Command::new(&self.pyre_path)
            .arg("--log-level")
            .arg("WARNING")
            .arg("analyze")
            .arg("--rule")
            .arg("9901")
            .arg("--save-results-to")
            .arg(&results_path)
            .current_dir(&self.project_dir)
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
    fn get_pyre_results(&self, results_dir: &Path) -> Result<Vec<TaintOutput>> {
        let file = File::open(results_dir.join(PYSA_TAINT_OUTPUT_NAME))?;
        let mut reader = BufReader::new(file);
        let mut header = String::new();
        reader.read_line(&mut header)?; // skip file header
        let header: TaintOutputHeader = serde_json::from_str(&header)?;

        if header.file_version != PYSA_TAINT_OUTPUT_SUPPORTED_VERSION {
            return Err(ToolError::PyreResultVersionMismatch {
                got: header.file_version,
                expected: PYSA_TAINT_OUTPUT_SUPPORTED_VERSION,
            }
            .into());
        }

        serde_json::Deserializer::from_reader(reader)
            .into_iter()
            .filter_map(|r| {
                r.map(|out| Some(out).filter(|out| matches!(out, TaintOutput::Issue(_))))
                    .map_err(|r| r.into())
                    .transpose()
            })
            .collect()
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
