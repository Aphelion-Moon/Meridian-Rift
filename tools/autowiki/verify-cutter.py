"""Recut every tracked icon configuration in isolation and compare complete outputs.

Requires Pillow, the repository DMI reader and the pinned hypnagogic executable.
Never changes game files. The output directory must not already exist.
"""
import argparse, importlib.util, json, pathlib, shutil, subprocess

REPO = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('cutter_recovery', pathlib.Path(__file__).with_name('recover-cutter-sources.py'))
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


def verify(output, cutter):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = output / 'inputs'
    inputs.mkdir()
    configs = subprocess.check_output(['git', '-C', str(REPO), 'ls-files', '-z', '*.png.toml', '*.dmi.toml'], timeout=30).decode().split('\0')
    rows = []
    for config in filter(None, configs):
        source = config[:-5]
        target = inputs / source
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / source, target)
        shutil.copy2(REPO / config, inputs / config)
        generated = source[:-4] + ('.dmi' if source.endswith('.png') else '.png')
        rows.append({'config': config, 'source': source, 'output': generated})
    with (output / 'cutter.log').open('wb') as log:
        subprocess.run([str(cutter.resolve()), '--dont-wait', '--templates', str(REPO / 'cutter_templates'), str(inputs)], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    for row in rows:
        try:
            original, generated = REPO / row['output'], inputs / row['output']
            row['originalSignature'] = recovery.icon_signature(original)
            row['generatedSignature'] = recovery.icon_signature(generated)
            row['semanticMatch'] = row['originalSignature'] == row['generatedSignature']
            row['byteMatch'] = original.read_bytes() == generated.read_bytes()
        except (OSError, ValueError, AssertionError, NotImplementedError) as error:
            row.update({'semanticMatch': False, 'byteMatch': False, 'error': type(error).__name__})
    report = {'version': 1, 'cutterSha256': recovery.digest(cutter.read_bytes()), 'configs': len(rows), 'semanticMatches': sum(row['semanticMatch'] for row in rows), 'byteMatches': sum(row['byteMatch'] for row in rows), 'rows': rows}
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: report[key] for key in ['configs', 'semanticMatches', 'byteMatches']}))
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--cutter', type=pathlib.Path, required=True)
    args = parser.parse_args()
    result = verify(args.output, args.cutter)
    if result['byteMatches'] != result['configs'] or result['semanticMatches'] != result['configs']:
        raise SystemExit(1)
