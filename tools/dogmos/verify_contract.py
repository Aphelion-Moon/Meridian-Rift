from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys
from typing import Any

HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")

class ContractError(ValueError):
    pass


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _duplicate_guard(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ContractError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _required_file(path: Path, description: str) -> bytes:
    if not path.is_file():
        raise ContractError(f"missing {description}: {path}")
    data = path.read_bytes()
    if not data:
        raise ContractError(f"empty {description}: {path}")
    return data


def _detect_architecture(data: bytes) -> tuple[str, str]:
    if data.startswith(b"MZ"):
        if len(data) < 64:
            raise ContractError("truncated PE artifact")
        offset = struct.unpack_from("<I", data, 0x3C)[0]
        if offset > len(data) - 6 or data[offset : offset + 4] != b"PE\0\0":
            raise ContractError("invalid PE artifact")
        machine = struct.unpack_from("<H", data, offset + 4)[0]
        architecture = {0x014C: "i686", 0x8664: "x86_64"}.get(machine)
        if architecture is None:
            raise ContractError(f"unsupported PE machine 0x{machine:04x}")
        return "pe", architecture
    if data.startswith(b"\x7fELF"):
        if len(data) < 20 or data[5] != 1:
            raise ContractError("invalid or non-little-endian ELF artifact")
        architecture = {(1, 3): "i686", (2, 62): "x86_64"}.get(
            (data[4], struct.unpack_from("<H", data, 18)[0])
        )
        if architecture is None:
            raise ContractError("unsupported ELF class or machine")
        return "elf", architecture
    raise ContractError("artifact is neither PE nor ELF")


def _decode_manifest(data: bytes) -> dict[str, Any]:
    if b"\r" in data or not data.endswith(b"\n") or data.endswith(b"\n\n"):
        raise ContractError("manifest must use LF and exactly one terminal LF")
    try:
        manifest = json.loads(data.decode("utf-8"), object_pairs_hook=_duplicate_guard)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ContractError(f"invalid manifest JSON: {error}") from error
    if not isinstance(manifest, dict):
        raise ContractError("manifest root must be an object")
    canonical = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    if canonical != data:
        raise ContractError("manifest JSON is not canonical")
    return manifest


def native_files(manifest: dict[str, Any]) -> tuple[str, str]:
    if manifest.get("target") == "i686-pc-windows-msvc":
        return "dogmos.dll", "dogmos.pdb"
    return "libdogmos_in_process.so", "libdogmos_in_process.so.debug"


def validate_in_process_manifest(manifest: dict[str, Any]) -> None:
    """Accept only a source-bound i686 native candidate."""
    if (manifest.get("schema_version") != 1
            or manifest.get("kind") != "unqualified-in-process-playtest"
            or manifest.get("backend") != "in-process"
            or manifest.get("target") not in ("i686-pc-windows-msvc", "i686-unknown-linux-gnu")
            or manifest.get("toolchain") != "1.98.0"
            or manifest.get("tests_run") is not False
            or manifest.get("runtime_qualified") is not False):
        raise ContractError("unsupported in-process play-test contract")
    for key, pattern in (("source_revision", HEX_40), ("source_sha256", HEX_64)):
        if not isinstance(manifest.get(key), str) or not pattern.fullmatch(manifest[key]):
            raise ContractError(f"invalid in-process {key}")
    features = ["aphelion_reactions", "katmos", "katmos_slow_decompression",
                "superconductivity", "turf_processing"]
    if manifest.get("features") != features:
        raise ContractError("in-process feature selection differs from the play-test contract")
    arguments = ["+1.98.0", "build", "-p", "dogmos", "--lib", "--example", "generate_bindings",
                 "--release", "--locked", "--target", manifest["target"],
                 "--no-default-features", "--features", ",".join(features)]
    if manifest.get("cargo_arguments") != arguments:
        raise ContractError("in-process build arguments differ from the play-test contract")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, dict) or set(artifacts) != {
            *native_files(manifest), "dogmos_bindings.dm", "dogmos-source-snapshot.json"}:
        raise ContractError("invalid in-process artifact set")
    if any(not isinstance(value, str) or not HEX_64.fullmatch(value) for value in artifacts.values()):
        raise ContractError("invalid in-process artifact digest")
    if artifacts["dogmos-source-snapshot.json"] != manifest["source_sha256"]:
        raise ContractError("in-process snapshot identity mismatch")


def verify_in_process_bytes(manifest: dict[str, Any], dll: bytes, bindings: bytes) -> None:
    validate_in_process_manifest(manifest)
    for name, data in ((native_files(manifest)[0], dll), ("dogmos_bindings.dm", bindings)):
        if _sha256(data) != manifest["artifacts"][name]:
            raise ContractError(f"in-process artifact does not match lock: {name}")
    expected_format = "pe" if manifest["target"] == "i686-pc-windows-msvc" else "elf"
    if _detect_architecture(dll) != (expected_format, "i686"):
        raise ContractError("in-process library has the wrong platform or architecture")
    identity = f'#define DOGMOS_IN_PROCESS_IDENTITY "in-process:{manifest["source_sha256"]}"'
    if (b"#define DOGMOS_IN_PROCESS\n" not in bindings
            or identity.encode() not in bindings
            or b'"libdogmos_in_process"' not in bindings
            or b'"libdogmos"' in bindings):
        raise ContractError("generated bindings select the wrong backend or source identity")


def render_contract_defines(manifest: dict[str, Any]) -> bytes:
    validate_in_process_manifest(manifest)
    return ("// Generated by tools/dogmos/verify_contract.py. Do not edit.\n"
            f'#define DOGMOS_CONTRACT_SOURCE_REVISION "{manifest["source_revision"]}"\n'
            f'#define DOGMOS_CONTRACT_SOURCE_SHA256 "{manifest["source_sha256"]}"\n'
            f'#define DOGMOS_CONTRACT_BINDINGS_SHA256 "{manifest["artifacts"]["dogmos_bindings.dm"]}"\n'
                '#define DOGMOS_CONTRACT_UNQUALIFIED_IN_PROCESS 1\n').encode()


def verify_installed(root: Path, *, target: str | None = None) -> dict[str, Any]:
    root = Path(root)
    target = target or ("i686-pc-windows-msvc" if sys.platform == "win32" else "i686-unknown-linux-gnu")
    lock_name = "dogmos.lock.json" if target == "i686-pc-windows-msvc" else "dogmos-linux.lock.json"
    manifest = _decode_manifest(_required_file(root / lock_name, "Dogmos lock"))
    if manifest.get("target") != target:
        raise ContractError("installed manifest target differs from requested platform")
    verify_in_process_bytes(manifest, _required_file(root / native_files(manifest)[0], "native library"),
                            _required_file(root / "code/__DEFINES/dogmos_bindings.dm", "bindings"))
    if _required_file(root / "code/__DEFINES/dogmos_contract.dm", "contract") != render_contract_defines(manifest):
        raise ContractError("generated in-process contract defines drifted from the lock")
    return manifest


def verify_qualification(root: Path, record_path: Path) -> dict[str, Any]:
    """Validate an external evidence record without promoting the artifact identity manifest."""
    record = json.loads(record_path.read_text(encoding="utf-8"), object_pairs_hook=_duplicate_guard)
    if not isinstance(record, dict) or record.get("schema_version") != 1 or record.get("kind") != "dogmos-qualification":
        raise ContractError("unsupported qualification record")
    manifest = verify_installed(root, target=record.get("target"))
    library = native_files(manifest)[0]
    identity = {
        "native_revision": manifest["source_revision"],
        "source_sha256": manifest["source_sha256"],
        "binary_sha256": manifest["artifacts"][library],
        "bindings_sha256": manifest["artifacts"]["dogmos_bindings.dm"],
        "features": manifest["features"],
        "target": manifest["target"],
    }
    if any(record.get(key) != value for key, value in identity.items()):
        raise ContractError("qualification does not match installed artifact identity")
    if not isinstance(record.get("game_revision"), str) or not HEX_40.fullmatch(record["game_revision"]):
        raise ContractError("qualification requires an exact game revision")
    if _sha256(_required_file(root / "tgstation.dmb", "qualified game binary")) != record.get("game_binary_sha256"):
        raise ContractError("qualification does not match the compiled game")
    workload = record.get("workload")
    if not isinstance(workload, dict) or not isinstance(workload.get("id"), str) or not workload["id"]:
        raise ContractError("qualification requires a named workload")
    if record.get("acceptance") != "human-reviewed":
        raise ContractError("qualification requires recorded human review of workload and results")
    evidence = record.get("evidence")
    if not isinstance(evidence, list) or not evidence:
        raise ContractError("qualification requires hashed evidence files")
    for entry in evidence:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise ContractError("invalid qualification evidence entry")
        path = (record_path.parent / entry["path"]).resolve()
        if not path.is_relative_to(record_path.parent.resolve()):
            raise ContractError("qualification evidence escapes record directory")
        if _sha256(_required_file(path, "qualification evidence")) != entry.get("sha256"):
            raise ContractError("qualification evidence digest mismatch")
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify the installed in-process Dogmos artifacts")
    commands = parser.add_subparsers(dest="command", required=True)
    installed = commands.add_parser("verify-installed")
    installed.add_argument("--root", type=Path, required=True)
    qualification = commands.add_parser("verify-qualification")
    qualification.add_argument("--root", type=Path, required=True)
    qualification.add_argument("--record", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "verify-qualification":
            verify_qualification(args.root, args.record)
        else:
            verify_installed(args.root)
        return 0
    except (ContractError, OSError, ValueError) as error:
        print(f"Dogmos contract verification failed: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
