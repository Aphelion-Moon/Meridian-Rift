#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output_dir="${1:-$script_dir/../..}"
test -d "$output_dir"
toolchain="1.89.0"
target="i686-unknown-linux-gnu"
# TGS invokes dependency installation in a child shell; its PATH does not propagate.
# Prepend rustup's bin so its cargo proxy wins over a distro cargo, which rejects +toolchain.
cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin"
export PATH="$cargo_bin:$PATH"
if ! command -v rustup >/dev/null 2>&1; then
  echo "rustup not found, installing to $cargo_bin..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain none --profile minimal
fi
# No-ops when already installed.
rustup toolchain install "$toolchain" --profile minimal --target "$target"
# The i686 target links against 32-bit libc, which rustup cannot provide.
if ! echo 'int main(void){return 0;}' | cc -m32 -x c - -o /dev/null >/dev/null 2>&1; then
  echo "error: cannot link 32-bit binaries. Install your distro's 32-bit C toolchain (e.g. gcc-multilib on Debian/Ubuntu, lib32-glibc on Arch, glibc-devel.i686 on Fedora)." >&2
  exit 1
fi
cargo "+$toolchain" test --locked --manifest-path "$script_dir/Cargo.toml" --target "$target"
cargo "+$toolchain" build --release --locked --manifest-path "$script_dir/Cargo.toml" --target "$target"
install -m 755 "$script_dir/target/$target/release/libmeridian_painting_store.so" "$output_dir/libmeridian_painting_store.so"
sha256sum "$output_dir/libmeridian_painting_store.so"
