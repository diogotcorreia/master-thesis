use std::{
    fs, io,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use anyhow::{Context, Result};
use tracing::debug;

#[derive(Debug)]
pub struct AnalyseOptions {
    pub work_dir: PathBuf,
    pub project_dir: PathBuf,
    pub pyre_path: PathBuf,
}

impl AnalyseOptions {
    pub fn run_analysis(&self) -> Result<()> {
        let _new_dir = self.copy_to_workdir()?;
        Ok(())
    }

    #[tracing::instrument]
    fn copy_to_workdir(&self) -> Result<PathBuf> {
        let destination_file_name = {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_millis();

            let mut file_name = self
                .project_dir
                .file_name()
                .map(|s| s.to_os_string())
                .unwrap_or("unknown".into());
            file_name.push(".");
            file_name.push(now.to_string());
            file_name
        };
        let destination = self.work_dir.join(destination_file_name).join("src");
        copy_dir_all(&self.project_dir, &destination)
            .context("failed to copy project into work dir")?;

        debug!("copied project to {destination:?}");

        Ok(destination)
    }
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
