#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bubblewrap

SCRIPT=$(readlink -f "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")

xdg_cache="${XDG_CACHE_HOME:-$HOME/.cache}"
uv_cache="$(realpath "${UV_CACHE_DIR:-$xdg_cache/uv}")"
workdir="$(realpath "$WORKDIR")"

script="$SCRIPT_PATH"/target/release/class-pollution-detection

pushd "$SCRIPT_PATH"
cargo build --release
popd

bwrap \
  --ro-bind /nix /nix \
  --ro-bind /etc /etc \
  --bind "$workdir" "$workdir" \
  --bind "$uv_cache" "$uv_cache" \
  --ro-bind "$script" "$script" \
  --proc /proc \
  --dev /dev \
  --setenv TMP /tmp \
  --setenv TMPDIR /tmp \
  --tmpfs /tmp \
  --tmpfs /run \
  --ro-bind /run/current-system /run/current-system \
  --ro-bind /sys /sys \
  --share-net \
  --die-with-parent \
  -- \
  $script $@
