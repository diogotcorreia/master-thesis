use std::{fs::File, io::Write, path::Path};

use anyhow::Result;

use crate::python::PyLock;

const DEFAULT_MODELS: &str = include_str!("../../taint-models/default.pysa");
const DEFAULT_PARTIAL_MODELS: &str = include_str!("../../taint-models/default-partial.pysa");
const DJANGO_MODELS: &str = include_str!("../../taint-models/django.pysa");
const FLASK_MODELS: &str = include_str!("../../taint-models/flask.pysa");
const SQLALCHEMY_MODELS: &str = include_str!("../../taint-models/sqlalchemy.pysa");

/// Calculate which taint models should be loaded based on the
/// dependencies present.
pub fn write_taint_models(
    dest: &Path,
    lockfile: &PyLock,
    require_user_controlled: bool,
) -> Result<()> {
    let mut file = File::create(dest)?;
    if require_user_controlled {
        writeln!(file, "{}", DEFAULT_PARTIAL_MODELS)?;
    } else {
        writeln!(file, "{}", DEFAULT_MODELS)?;
    }

    for package in lockfile.packages.iter() {
        #[allow(clippy::single_match)]
        match package.name.as_str() {
            "django" => writeln!(file, "{}", DJANGO_MODELS)?,
            "flask" => writeln!(file, "{}", FLASK_MODELS)?,
            "sqlalchemy" => writeln!(file, "{}", SQLALCHEMY_MODELS)?,
            _ => {}
        }
    }
    Ok(())
}
