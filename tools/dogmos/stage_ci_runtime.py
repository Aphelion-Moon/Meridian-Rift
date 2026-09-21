"""Stage the verified Linux in-process library for DreamDaemon."""
import argparse
from pathlib import Path
import shutil
import sys
import verify_contract as contract


def stage_runtime(root: Path, destination: Path) -> None:
    manifest = contract.verify_installed(root, target="i686-unknown-linux-gnu")
    if manifest['target'] != 'i686-unknown-linux-gnu':
        raise contract.ContractError('Linux runtime requires a Linux native bundle')
    name = contract.native_files(manifest)[0]
    shutil.copyfile(root / name, destination / name)
    if contract._sha256((destination / name).read_bytes()) != manifest['artifacts'][name]:
        raise contract.ContractError('staged Linux library hash mismatch')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    try:
        stage_runtime(args.root, args.destination)
        return 0
    except (contract.ContractError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
