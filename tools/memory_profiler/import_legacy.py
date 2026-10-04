"""Explicitly count-only Nova PR 6615 CSV / builtin proc or SendMaps adapter.

The original records are preserved in comparison_context, never represented as
deduplicated heap bytes. Converts without executing or evaluating imported text.
"""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path


def convert(path, kind):
    raw = path.read_bytes()
    if len(raw) > 16 * 1024 * 1024:
        raise ValueError('16 MiB import limit')
    text = raw.decode('utf-8-sig')
    if kind == 'nova-csv':
        rows = list(csv.DictReader(io.StringIO(text)))
        required = {'Path', 'Instances', 'List Count', 'Recursive length'}
        if rows and not required.issubset(rows[0]):
            raise ValueError('Expected original PR 6615 column names')
    else:
        rows = json.loads(text)
        if not isinstance(rows, list):
            raise ValueError('Expected builtin JSON row array')
    if len(rows) > 10000:
        raise ValueError('10,000 legacy row limit')
    capture = {'schema_version': 1, 'collector_version': 'legacy-adapter-1',
        'provenance': {'capture_id': path.stem, 'evidence_class': f'imported_{kind}', 'byond': 'unknown'},
        'coverage': {'scope': kind, 'status': 'partial', 'reason': 'legacy_report_has_no_identity_graph',
        'limitations': ['Legacy totals may double-charge shared lists; builtin exports measure time/calls, not memory. Original rows are in comparison_context.']},
        'quality': {}, 'models': [], 'observations': {'nodes': [], 'edges': []},
        'comparison_context': {'legacy_format': kind, 'legacy_rows': rows},
        'evidence': [{'artifact': path.name, 'sha256': hashlib.sha256(raw).hexdigest()}]}
    return capture


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('format', choices=['nova-csv', 'proc', 'sendmaps'])
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_text(json.dumps(convert(args.input, args.format), indent=2) + '\n', encoding='utf-8')
