#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output_dir="${1:-$script_dir/../..}"
test -d "$output_dir"
# TGS invokes dependency installation in a child shell; its PATH does not propagate.
if [ -x "$HOME/.cargo/bin/cargo" ]; then
  export PATH="$HOME/.cargo/bin:$PATH"
fi
cargo +1.89.0 test --locked --manifest-path "$script_dir/Cargo.toml" --target i686-unknown-linux-gnu
cargo +1.89.0 build --release --locked --manifest-path "$script_dir/Cargo.toml" --target i686-unknown-linux-gnu
install -m 755 "$script_dir/target/i686-unknown-linux-gnu/release/libmeridian_painting_store.so" "$output_dir/libmeridian_painting_store.so"
sha256sum "$output_dir/libmeridian_painting_store.so"
