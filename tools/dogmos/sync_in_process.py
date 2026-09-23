"""Install a matching, explicitly unqualified native bundle into a development checkout."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from verify_contract import (ContractError, _duplicate_guard, render_contract_defines,
                             validate_in_process_manifest, verify_in_process_bytes, verify_installed, native_files)


def atomic_write(path: Path, data: bytes) -> None:
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".dogmos-install-", delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(data)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def read_bundle(bundle: Path, native_root: Path) -> tuple[dict, dict]:
    """Validate every candidate before any installation write."""
    manifest = json.loads((bundle / "dogmos-playtest.json").read_text(encoding="utf-8-sig"),
                          object_pairs_hook=_duplicate_guard)
    validate_in_process_manifest(manifest)
    artifacts = {name: (bundle / name).read_bytes() for name in manifest["artifacts"]}
    for name, data in artifacts.items():
        if hashlib.sha256(data).hexdigest() != manifest["artifacts"][name]:
            raise ContractError(f"bundle hash mismatch: {name}")
    library = native_files(manifest)[0]
    verify_in_process_bytes(manifest, artifacts[library], artifacts["dogmos_bindings.dm"])
    import sys
    subprocess.run([sys.executable, "-B", str(native_root / "tools/dogmos_source_snapshot.py"),
                    "verify", "--repository-root", str(native_root),
                    "--snapshot", str(bundle / "dogmos-source-snapshot.json")], check=True)
    return manifest, artifacts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--companion-bundle", type=Path,
                        help="Update the second platform together from the same source, with failure rollback")
    parser.add_argument("--native-root", type=Path, required=True)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    root = args.root.resolve()
    bundles = [read_bundle(args.bundle.resolve(), args.native_root.resolve())]
    if args.companion_bundle:
        bundles.append(read_bundle(args.companion_bundle.resolve(), args.native_root.resolve()))
    if not (root / "tgstation.dme").is_file():
        raise ContractError("destination is not a Meridian-Rift checkout")
    manifest = bundles[0][0]
    targets = set()
    replacements = {}
    for candidate, artifacts in bundles:
        if candidate["target"] in targets:
            raise ContractError("companion bundle must target the other platform")
        targets.add(candidate["target"])
        if (candidate["source_sha256"] != manifest["source_sha256"]
                or candidate["artifacts"]["dogmos_bindings.dm"] != manifest["artifacts"]["dogmos_bindings.dm"]):
            raise ContractError("paired bundles must have identical source and bindings")
        library = native_files(candidate)[0]
        lock_name = "dogmos.lock.json" if candidate["target"] == "i686-pc-windows-msvc" else "dogmos-linux.lock.json"
        replacements.update({
            root / library: artifacts[library],
            root / "code/__DEFINES/dogmos_bindings.dm": artifacts["dogmos_bindings.dm"],
            root / "code/__DEFINES/dogmos_contract.dm": render_contract_defines(candidate),
            root / lock_name: (json.dumps(candidate, indent=2, sort_keys=True) + "\n").encode(),
        })
    for lock_name, target in (("dogmos.lock.json", "i686-pc-windows-msvc"),
                              ("dogmos-linux.lock.json", "i686-unknown-linux-gnu")):
        other_lock = root / lock_name
        if target in targets or not other_lock.exists():
            continue
        other = json.loads(other_lock.read_text(encoding="utf-8-sig"), object_pairs_hook=_duplicate_guard)
        if (other.get("source_sha256") != manifest["source_sha256"]
                or other.get("artifacts", {}).get("dogmos_bindings.dm") != manifest["artifacts"]["dogmos_bindings.dm"]):
            raise ContractError("other installed platform differs; supply its matching --companion-bundle")
    previous = {path: path.read_bytes() if path.exists() else None for path in replacements}
    try:
        for path, data in replacements.items():
            atomic_write(path, data)
        for target in targets:
            verify_installed(root, target=target)
    except BaseException:
        for path, data in previous.items():
            if data is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, data)
        raise
    print(f"Installed in-process candidate {manifest['source_sha256']}; runtime qualification deferred.")


if __name__ == "__main__":
    main()
