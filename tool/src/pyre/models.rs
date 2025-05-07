use std::{fs::File, io::Write, path::Path};

use anyhow::Result;

use crate::python::PyLock;

const DEFAULT_MODELS: &str = include_str!("../../taint-models/default.pysa");
const DJANGO_MODELS: &str = include_str!("../../taint-models/django.pysa");
const FLASK_MODELS: &str = include_str!("../../taint-models/flask.pysa");

/// Calculate which taint models should be loaded based on the
/// dependencies present.
pub fn write_taint_models(dest: &Path, lockfile: PyLock) -> Result<()> {
    let mut file = File::create(dest)?;
    writeln!(file, "{}", DEFAULT_MODELS)?;

    for package in lockfile.packages.iter() {
        #[allow(clippy::single_match)]
        match package.name.as_str() {
            "django" => writeln!(file, "{}", DJANGO_MODELS)?,
            "flask" => writeln!(file, "{}", FLASK_MODELS)?,
            _ => {}
        }
    }
    Ok(())
}
