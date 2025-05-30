use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use cli::Cli;
use tempdir::TempDir;
use tracing::debug;

pub mod analyse;
pub mod cli;
pub mod e2e;
pub mod errors;
pub mod pyre;
pub mod python;

pub enum Workdir {
    TempDir(TempDir),
    PersistDir(PathBuf),
}

impl Workdir {
    pub fn from_cli(cli: &Cli) -> Result<Self> {
        if let Some(path) = &cli.workdir {
            debug!("using existing work dir at {:?}", path);
            Ok(Workdir::PersistDir(path.clone()))
        } else {
            let workdir = TempDir::new("class-pollution-detection")
                .context("failed to create work dir in temporary directory")?;
            debug!("created work dir at {:?}", workdir.path());
            if cli.keep_workdir {
                Ok(Workdir::PersistDir(workdir.into_path()))
            } else {
                Ok(Workdir::TempDir(workdir))
            }
        }
    }

    pub fn path(&self) -> &Path {
        match self {
            Self::TempDir(temp_dir) => temp_dir.path(),
            Self::PersistDir(path_buf) => path_buf.as_path(),
        }
    }

    pub fn close(self) -> Result<()> {
        match self {
            Workdir::TempDir(temp_dir) => {
                temp_dir
                    .close()
                    .context("failed to delete work dir in temporary directory")?;
                debug!("deleted work dir");
            }
            Workdir::PersistDir(_) => {
                debug!("keeping work dir");
            }
        }
        Ok(())
    }
}
