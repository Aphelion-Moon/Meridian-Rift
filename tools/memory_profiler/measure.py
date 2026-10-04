"""Disposable BYOND process telemetry/calibration. Standard library only.

Windows private bytes and working set are independent metrics. Linux reports RSS
and private resident bytes (NOT Windows private commit). Never target an existing PID.
"""
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import time


def memory(process):
    if os.name == 'nt':
        class Counters(ctypes.Structure):
            _fields_ = [('cb', ctypes.c_ulong), ('PageFaultCount', ctypes.c_ulong)] + [
                (name, ctypes.c_size_t) for name in ('PeakWorkingSetSize', 'WorkingSetSize',
                'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage', 'QuotaPeakNonPagedPoolUsage',
                'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage', 'PrivateUsage')]
        counters = Counters()
        counters.cb = ctypes.sizeof(counters)
        api = ctypes.WinDLL('psapi', use_last_error=True).GetProcessMemoryInfo
        api.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ulong]
        if not api(int(process._handle), ctypes.byref(counters), counters.cb):
            raise ctypes.WinError(ctypes.get_last_error())
        class FileTime(ctypes.Structure):
            _fields_ = [('low', ctypes.c_ulong), ('high', ctypes.c_ulong)]
        times = [FileTime() for _ in range(4)]
        api_times = ctypes.WinDLL('kernel32', use_last_error=True).GetProcessTimes
        api_times.argtypes = [ctypes.c_void_p] + [ctypes.c_void_p] * 4
        if not api_times(int(process._handle), *(ctypes.byref(v) for v in times)):
            raise ctypes.WinError(ctypes.get_last_error())
        cpu_ms = sum((v.high << 32) + v.low for v in times[2:]) / 10000
        return {'working_set_bytes': counters.WorkingSetSize, 'private_commit_bytes': counters.PrivateUsage, 'cpu_ms': cpu_ms}
    metrics = {}
    for line in Path(f'/proc/{process.pid}/smaps_rollup').read_text().splitlines():
        fields = line.split()
        if fields[0] in ('Rss:', 'Private_Clean:', 'Private_Dirty:'):
            metrics[fields[0]] = int(fields[1]) * 1024
    return {'rss_bytes': metrics.get('Rss:'), 'private_resident_bytes': metrics.get('Private_Clean:', 0) + metrics.get('Private_Dirty:', 0)}


def run(daemon, dmb, directory, params='', timeout=180, copy_binary=True, game_dir=None):
    directory.mkdir(parents=True, exist_ok=False)
    if copy_binary:
        target = directory / dmb.name
        shutil.copy2(dmb, target)
    else:
        target = dmb
    # Full game requires native rust-g/dreamluau. Disposable standalone fixtures
    # stay in safe mode; game mode is explicit and uses the authorized checkout.
    args = [str(daemon), str(target), '-invisible', '-trusted' if game_dir else '-safe', '-params', params]
    if game_dir:
        args += ['-cd', str(game_dir)]
    samples, markers, seen = [], [], set()
    started = time.monotonic()
    with (directory / 'runtime.log').open('w') as log:
        process = subprocess.Popen(args, cwd=directory, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        try:
            while process.poll() is None:
                elapsed = (time.monotonic() - started) * 1000
                if elapsed > timeout * 1000:
                    raise TimeoutError(f'Owned test process exceeded {timeout}s')
                try:
                    samples.append({'offset_ms': round(elapsed, 3), **memory(process)})
                except (OSError, ProcessLookupError):
                    if process.poll() is None:
                        raise
                for marker in (game_dir or directory).glob('*.marker'):
                    if marker.name not in seen:
                        seen.add(marker.name)
                        markers.append({'name': marker.stem, 'offset_ms': round(elapsed, 3)})
                time.sleep(0.1)
            if process.returncode:
                raise RuntimeError(f'Dream Daemon exited {process.returncode}; see {directory / "runtime.log"}')
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            evidence = {'process_samples': samples, 'markers': markers, 'command': args,
                        'exit_code': process.returncode, 'platform': os.name,
                        'dmb_sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                        'sampling_interval_ms': 100, 'pid': process.pid}
            (directory / 'telemetry.json').write_text(json.dumps(evidence, indent=2) + '\n')
    return evidence


def plateau(evidence, name, metric):
    markers = evidence['markers']
    current = next(m for m in markers if m['name'] == name)
    later = [m['offset_ms'] for m in markers if m['offset_ms'] > current['offset_ms']]
    end = min(later, default=float('inf'))
    # Prefer last stable 0.8s of each 1.5s plateau, before next allocation phase.
    points = [s[metric] for s in evidence['process_samples'] if current['offset_ms'] + 500 <= s['offset_ms'] <= min(current['offset_ms'] + 1300, end)]
    if not points:
        raise ValueError('Missing plateau samples')
    return statistics.median(points)


def calibrate(args):
    rows = []
    cases = [('list', n) for n in (0, 8, 32, 128, 64, 96)] + [('assoc', 32), ('alist', 32), ('shrink', 128), ('datum_empty', 0), ('datum_fields', 0)]
    for family, size in cases:
        for repetition in range(3):
            count = 12000
            name = f'{family}-{size}-{repetition}'
            evidence = run(args.daemon, args.dmb, args.out / name, f'family={family}&size={size}&count={count}', timeout=90)
            expected = f'CALIBRATION_DONE family={family} count={count} size={size}'
            if expected not in (args.out / name / 'runtime.log').read_text():
                raise ValueError(f'Workload marker mismatch: {name}; calibration rejected')
            metric = 'private_commit_bytes' if os.name == 'nt' else 'private_resident_bytes'
            delta = plateau(evidence, 'allocated', metric) - plateau(evidence, 'baseline', metric)
            row = {'family': family, 'size': size, 'count': count, 'repetition': repetition, 'delta_bytes': delta,
                   'bytes_per_object': delta / count, 'metric': metric, 'artifact': f'{name}/telemetry.json'}
            if family == 'shrink':
                row['after_shrink_delta_bytes'] = plateau(evidence, 'shrunk', metric) - plateau(evidence, 'baseline', metric)
            rows.append(row)
            print(json.dumps(row), flush=True)
            (args.out / 'raw-calibration.json').write_text(json.dumps(rows, indent=2) + '\n')
    fit_model(rows, args.out, args.byond)


def fit_model(rows, directory, byond):
    # Empty lists are a different allocation family; do not fit a single affine
    # model through zero and silently overestimate common empty containers.
    training = [r for r in rows if r['family'] == 'list' and r['size'] in (8, 32, 128)]
    xs = [r['size'] for r in training]; ys = [r['bytes_per_object'] for r in training]
    mean_x, mean_y = statistics.mean(xs), statistics.mean(ys)
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / sum((x - mean_x) ** 2 for x in xs)
    intercept = mean_y - slope * mean_x
    holdout = [r for r in rows if r['family'] == 'list' and r['size'] == 96]
    errors = [abs(intercept + slope * 96 - r['bytes_per_object']) / max(1, r['bytes_per_object']) for r in holdout]
    empty = [r['bytes_per_object'] for r in rows if r['family'] == 'list' and r['size'] == 0]
    model = {'schema_version': 1, 'model_id': f'byond-{byond}-{os.name}-fresh-list-v2', 'byond': byond,
             'os': 'MS Windows' if os.name == 'nt' else 'UNIX',
             'architecture': 'x86', 'metric': training[0]['metric'], 'families': [{'kind': 'list',
             'intercept': intercept, 'slope': slope, 'min_length': 8, 'max_length': 128,
             'supported': os.name == 'nt' and intercept >= 0 and slope >= 0 and bool(errors) and max(errors) <= .2},
             {'kind': 'list', 'intercept': statistics.median(empty), 'slope': 0, 'min_length': 0, 'max_length': 0,
              'supported': os.name == 'nt', 'basis': 'Three independent empty-list populations; empirical equivalent, not a capacity guarantee.'}],
             'holdout_size': 96, 'holdout_relative_errors': errors, 'calibration_sha256': hashlib.sha256((directory / 'raw-calibration.json').read_bytes()).hexdigest(),
             'limitations': 'Fresh null-filled lists, process-private-commit delta/population; allocator/page rounding, no confidence interval, historical capacity unknown. Datum/associative rows are family-specific observations, not universal coefficients.'}
    (directory / 'model.json').write_text(json.dumps(model, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['run', 'calibrate'])
    parser.add_argument('--daemon', type=Path, required=True)
    parser.add_argument('--dmb', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--byond', default='516.1687')
    parser.add_argument('--params', default='')
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('--game-dir', type=Path, help='Use this isolated game checkout as the daemon working directory; do not target production.')
    args = parser.parse_args()
    args.daemon = args.daemon.resolve(); args.dmb = args.dmb.resolve(); args.out = args.out.resolve()
    if args.command == 'calibrate':
        args.out.mkdir(parents=True, exist_ok=False)
        calibrate(args)
    else:
        run(args.daemon, args.dmb, args.out, args.params, args.timeout, not bool(args.game_dir), args.game_dir.resolve() if args.game_dir else None)
