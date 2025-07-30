use std::{fs::File, io::Write, path::Path};

use anyhow::Result;

const DEFAULT_MODELS: &str = include_str!("../../taint-models/default.pysa");

pub fn write_taint_models(dest: &Path) -> Result<()> {
    let mut file = File::create(dest)?;
    writeln!(file, "{}", DEFAULT_MODELS)?;

    Ok(())
}
