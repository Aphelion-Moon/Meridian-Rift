from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
from typing import Any


HEX_40 = re.compile(r"^[0-9a-f]{40}$")
HEX_64 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_ARTIFACTS = {
    ("linux", "service"): ("x86_64-unknown-linux-gnu", "x86_64", "elf"),
    ("linux", "shim"): ("i686-unknown-linux-gnu", "i686", "elf"),
    ("windows", "service"): ("x86_64-pc-windows-msvc", "x86_64", "pe"),
    ("windows", "shim"): ("i686-pc-windows-msvc", "i686", "pe"),
}
INSTALLED_ARTIFACTS = {
    ("linux", "service"): "dogmosd",
    ("linux", "shim"): "libdogmos.so",
    ("windows", "service"): "dogmosd.exe",
    ("windows", "shim"): "dogmos.dll",
}


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


def _safe_name(name: Any, description: str) -> str:
    if not isinstance(name, str) or not name:
        raise ContractError(f"invalid {description} path")
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or "\\" in name:
        raise ContractError(f"unsafe {description} path: {name!r}")
    if path.as_posix() != name or name.startswith("./"):
        raise ContractError(f"noncanonical {description} path: {name!r}")
    return name


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


def _validate_record(record: Any, description: str) -> None:
    if not isinstance(record, dict):
        raise ContractError(f"invalid {description} record")
    _safe_name(record.get("file"), description)
    digest = record.get("sha256")
    if not isinstance(digest, str) or not HEX_64.fullmatch(digest):
        raise ContractError(f"invalid {description} digest")
    if not isinstance(record.get("size"), int) or record["size"] <= 0:
        raise ContractError(f"invalid {description} size")


def _validate_structure(manifest: dict[str, Any]) -> None:
    if manifest.get("schema_version") != 1:
        raise ContractError("unsupported Dogmos contract schema")
    if manifest.get("build_profile") != "release":
        raise ContractError("Dogmos contract is not a release build")
    revision = manifest.get("source_revision")
    if not isinstance(revision, str) or not HEX_40.fullmatch(revision):
        raise ContractError("Dogmos contract has an invalid source revision")
    capabilities = manifest.get("capabilities")
    if not isinstance(capabilities, dict):
        raise ContractError("Dogmos contract has no capabilities")
    features = capabilities.get("features")
    if not isinstance(features, list) or features != sorted(set(features)):
        raise ContractError("Dogmos features must be sorted and unique")
    fingerprint = capabilities.get("feature_fingerprint")
    if not isinstance(fingerprint, str) or not HEX_64.fullmatch(fingerprint):
        raise ContractError("Dogmos feature fingerprint is invalid")
    toolchain = manifest.get("toolchain")
    if not isinstance(toolchain, dict):
        raise ContractError("Dogmos contract has no toolchain")
    if not re.fullmatch(r"\d+\.\d+\.\d+", toolchain.get("rust", "")):
        raise ContractError("Dogmos Rust version is invalid")
    if not re.fullmatch(r"\d+\.\d+", toolchain.get("byond", "")):
        raise ContractError("Dogmos BYOND version is invalid")
    if not HEX_40.fullmatch(toolchain.get("byondapi_revision", "")):
        raise ContractError("Dogmos byondapi revision is invalid")
    versions = manifest.get("versions")
    if not isinstance(versions, dict) or set(versions) != {
        "abi",
        "dogmos-byond",
        "dogmos-server",
        "protocol",
        "workspace",
    }:
        raise ContractError("Dogmos contract version fields are invalid")
    if not isinstance(versions["abi"], int) or not isinstance(
        versions["protocol"], int
    ):
        raise ContractError("Dogmos ABI and protocol versions must be integers")
    for package in ("dogmos-byond", "dogmos-server", "workspace"):
        if not re.fullmatch(r"\d+\.\d+\.\d+", versions[package]):
            raise ContractError(f"Dogmos {package} version is invalid")
    _validate_record(manifest.get("bindings"), "bindings")
    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or len(artifacts) != 4:
        raise ContractError("Dogmos contract requires four platform artifacts")
    pairs = []
    names = {manifest["bindings"]["file"]}
    for artifact in artifacts:
        _validate_record(artifact, "artifact")
        pair = (artifact.get("platform"), artifact.get("role"))
        expected = EXPECTED_ARTIFACTS.get(pair)
        if expected is None or pair in pairs:
            raise ContractError(f"unexpected or duplicate artifact pair: {pair}")
        pairs.append(pair)
        target, architecture, artifact_format = expected
        if (
            artifact.get("target"),
            artifact.get("architecture"),
            artifact.get("format"),
        ) != (target, architecture, artifact_format):
            raise ContractError(f"artifact identity mismatch: {pair}")
        _validate_record(artifact.get("symbols"), "symbols")
        for name in (artifact["file"], artifact["symbols"]["file"]):
            if name in names:
                raise ContractError(f"duplicate contract path: {name}")
            names.add(name)
    if pairs != sorted(EXPECTED_ARTIFACTS):
        raise ContractError("Dogmos artifacts are not in canonical order")


def _verify_record(record: dict[str, Any], root: Path, description: str) -> bytes:
    data = _required_file(root / PurePosixPath(record["file"]), description)
    if len(data) != record["size"] or _sha256(data) != record["sha256"]:
        raise ContractError(f"{description} hash or size mismatch: {record['file']}")
    return data


def validate_release(data: bytes, bundle_root: Path) -> dict[str, Any]:
    manifest = _decode_manifest(data)
    _validate_structure(manifest)
    bundle_root = Path(bundle_root)
    _verify_record(manifest["bindings"], bundle_root, "bindings")
    for artifact in manifest["artifacts"]:
        binary = _verify_record(artifact, bundle_root, "artifact")
        detected = _detect_architecture(binary)
        if detected != (artifact["format"], artifact["architecture"]):
            raise ContractError(
                f"artifact byte architecture mismatch: {artifact['platform']}/{artifact['role']}"
            )
        _verify_record(artifact["symbols"], bundle_root, "symbols")
    return manifest


def _artifact(manifest: dict[str, Any], platform: str, role: str) -> dict[str, Any]:
    return next(
        artifact
        for artifact in manifest["artifacts"]
        if artifact["platform"] == platform and artifact["role"] == role
    )


def render_contract_defines(manifest: dict[str, Any]) -> bytes:
    values = manifest["versions"]
    capabilities = manifest["capabilities"]
    lines = [
        "// Generated by tools/dogmos/verify_contract.py. Do not edit.",
        f"#define DOGMOS_CONTRACT_SCHEMA_VERSION {manifest['schema_version']}",
        f"#define DOGMOS_CONTRACT_ABI_VERSION {values['abi']}",
        f"#define DOGMOS_CONTRACT_PROTOCOL_VERSION {values['protocol']}",
        f'#define DOGMOS_CONTRACT_SOURCE_REVISION "{manifest["source_revision"]}"',
        f'#define DOGMOS_CONTRACT_FEATURE_FINGERPRINT "{capabilities["feature_fingerprint"]}"',
        f'#define DOGMOS_CONTRACT_BYOND_VERSION "{manifest["toolchain"]["byond"]}"',
        f'#define DOGMOS_CONTRACT_BINDINGS_SHA256 "{manifest["bindings"]["sha256"]}"',
    ]
    for platform, role in sorted(EXPECTED_ARTIFACTS):
        artifact = _artifact(manifest, platform, role)
        macro = f"DOGMOS_CONTRACT_{platform}_{role}_SHA256".upper()
        lines.append(f'#define {macro} "{artifact["sha256"]}"')
    return ("\n".join(lines) + "\n").encode()


def verify_installed(root: Path) -> dict[str, Any]:
    root = Path(root)
    lock_bytes = _required_file(root / "dogmos.lock.json", "Dogmos lock")
    manifest = _decode_manifest(lock_bytes)
    _validate_structure(manifest)
    bindings_path = root / "code" / "__DEFINES" / "dogmos_bindings.dm"
    bindings = _required_file(bindings_path, "installed bindings")
    if (
        len(bindings) != manifest["bindings"]["size"]
        or _sha256(bindings) != manifest["bindings"]["sha256"]
    ):
        raise ContractError("installed bindings do not match dogmos.lock.json")
    for pair, relative_path in INSTALLED_ARTIFACTS.items():
        artifact = _artifact(manifest, *pair)
        binary = _required_file(root / relative_path, f"installed {pair}")
        if len(binary) != artifact["size"] or _sha256(binary) != artifact["sha256"]:
            raise ContractError(f"installed artifact does not match lock: {relative_path}")
        if _detect_architecture(binary) != (
            artifact["format"],
            artifact["architecture"],
        ):
            raise ContractError(f"installed artifact architecture mismatch: {relative_path}")
    defines = _required_file(
        root / "code" / "__DEFINES" / "dogmos_contract.dm",
        "generated Dogmos contract defines",
    )
    if defines != render_contract_defines(manifest):
        raise ContractError("generated Dogmos contract defines drifted from the lock")
    return manifest


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Verify a Meridian-Rift Dogmos contract")
    commands = parser.add_subparsers(dest="command", required=True)
    release = commands.add_parser("validate-release")
    release.add_argument("--manifest", type=Path, required=True)
    release.add_argument("--bundle-root", type=Path, required=True)
    render = commands.add_parser("render-defines")
    render.add_argument("--manifest", type=Path, required=True)
    render.add_argument("--bundle-root", type=Path, required=True)
    render.add_argument("--output", type=Path, required=True)
    installed = commands.add_parser("verify-installed")
    installed.add_argument("--root", type=Path, required=True)
    return parser


def main() -> int:
    arguments = _parser().parse_args()
    try:
        if arguments.command == "verify-installed":
            verify_installed(arguments.root)
            return 0
        manifest_bytes = arguments.manifest.read_bytes()
        manifest = validate_release(manifest_bytes, arguments.bundle_root)
        if arguments.command == "render-defines":
            arguments.output.write_bytes(render_contract_defines(manifest))
        return 0
    except (ContractError, OSError) as error:
        print(f"Dogmos contract verification failed: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
