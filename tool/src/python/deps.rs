use std::{
    fs::{self, DirEntry},
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{bail, Context, Result};
use itertools::Itertools;
use serde::Deserialize;
use tracing::debug;

use crate::errors::ToolError;

use super::{PyLock, PyProject};

const LOCKFILE_NAME: &str = "pylock.toml";

#[derive(Debug, Default, Deserialize)]
#[serde(default)]
pub struct ResolveDependenciesOpts {
    pub denylisted_packages: Vec<String>,
    pub additional_wheel_repos: Vec<String>,
}

pub fn compile_pylock(
    workdir: &Path,
    src_dir: &Path,
    opts: &ResolveDependenciesOpts,
) -> Result<(PathBuf, PyLock)> {
    let dependency_files = discover_dependency_files(src_dir)?;
    let dependency_files = export_existing_lockfiles(workdir, dependency_files)?;
    let dependency_files = dependency_files.iter().filter(|dep| {
        // Ignore setup.py if there are other dependency files.
        // This is because executing setup.py usually requires installing dependencies,
        // entering a catch-22 situation: https://peps.python.org/pep-0518/#rationale
        !matches!(dep.kind, DependencyFileKind::SetupPy) || dependency_files.len() == 1
    });

    let supports_extras = dependency_files
        .clone()
        .any(|dep| dep.kind.supports_extras());
    let groups_args = dependency_files
        .clone()
        .flat_map(|dep| match &dep.kind {
            DependencyFileKind::PyProject { groups } => groups.as_slice(),
            _ => &[],
        })
        .flat_map(|group| ["--group", group]);
    let dependency_files_args = dependency_files.map(|dep| dep.path.as_path());
    let excluded_packages = opts
        .denylisted_packages
        .iter()
        .flat_map(|dep| ["--no-emit-package", dep]);
    let find_links = opts
        .additional_wheel_repos
        .iter()
        .flat_map(|repo| ["--find-links", repo]);

    let lockfile_path = workdir.join(LOCKFILE_NAME);
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
        .args(groups_args)
        .args(excluded_packages)
        .args(find_links)
        .arg("--")
        .args(dependency_files_args)
        .current_dir(src_dir)
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

#[derive(Debug)]
enum DependencyFileKind {
    PyProject { groups: Vec<String> },
    SetupPy,
    SetupCfg,
    Requirements,

    UvLock,
    PyLock,
}

impl DependencyFileKind {
    fn supports_extras(&self) -> bool {
        matches!(
            self,
            DependencyFileKind::PyProject { .. }
                | DependencyFileKind::SetupPy
                | DependencyFileKind::SetupCfg
        )
    }
}

struct DependencyFile {
    kind: DependencyFileKind,
    path: PathBuf,
}

impl DependencyFile {
    fn from_dir_entry(entry: &DirEntry) -> Result<Option<Self>> {
        let Ok(name) = entry.file_name().into_string() else {
            return Ok(None);
        };
        if !entry.file_type()?.is_file() {
            return Ok(None);
        }

        let kind = if name == "pyproject.toml" {
            let pyproject_content =
                fs::read_to_string(entry.path()).context("failed to read pyproject.toml")?;
            let lockfile: PyProject =
                toml::from_str(&pyproject_content).context("failed to parse pyproject.toml")?;
            let groups = lockfile.dependency_groups.into_keys().collect_vec();
            Some(DependencyFileKind::PyProject { groups })
        } else if name == "setup.py" || name == "setup.cfg" {
            Some(DependencyFileKind::SetupPy)
        } else if name == "setup.cfg" {
            Some(DependencyFileKind::SetupCfg)
        } else if name == "uv.lock" {
            Some(DependencyFileKind::UvLock)
        } else if name.starts_with("pylock.") && name.ends_with(".toml") {
            Some(DependencyFileKind::PyLock)
        } else if name.starts_with("requirements") && name.ends_with(".txt") {
            Some(DependencyFileKind::Requirements)
        } else {
            None
        };

        Ok(kind.map(|k| Self {
            path: entry.path(),
            kind: k,
        }))
    }
}

/// Finds files that contain dependency information in the project's src directory.
/// Candidate files are pyproject.toml, requirements*.txt, setup.py and setup.cfg.
/// Only files at the root of the project are considered.
fn discover_dependency_files(src_dir: &Path) -> Result<Vec<DependencyFile>> {
    src_dir.read_dir()?.process_results(|iter| {
        iter.filter_map(|entry| DependencyFile::from_dir_entry(&entry).transpose())
            .try_collect()
    })?
}

fn export_existing_lockfiles(
    workdir: &Path,
    mut dependencies: Vec<DependencyFile>,
) -> Result<Vec<DependencyFile>> {
    for (i, dep) in dependencies.iter_mut().enumerate() {
        match &dep.kind {
            DependencyFileKind::UvLock => {
                let dir = dep.path.parent().expect("uv.lock to have a parent dir");
                let requirements_output = workdir.join(format!("requirements-{}.txt", i));
                let output = Command::new("uv")
                    .arg("export")
                    .arg("--all-extras")
                    .arg("--all-groups")
                    .arg("--all-packages")
                    .arg("--frozen")
                    .arg("--no-config")
                    .arg("--format")
                    .arg("requirements.txt")
                    .arg("--output-file")
                    .arg(&requirements_output)
                    .current_dir(dir)
                    .output()
                    .context("failed to resolve dependencies")?;
                if output.status.success() {
                    debug!("ran uv export and saved results to {requirements_output:?}");
                    *dep = DependencyFile {
                        path: requirements_output,
                        kind: DependencyFileKind::Requirements,
                    };
                } else {
                    return Err(ToolError::UvError {
                        stdout: String::from_utf8(output.stdout)?,
                        stderr: String::from_utf8(output.stderr)?,
                    }
                    .into());
                }
            }
            DependencyFileKind::PyLock => {
                bail!("pylock support is not completed");
            }
            _ => {}
        }
    }

    Ok(dependencies)
}
