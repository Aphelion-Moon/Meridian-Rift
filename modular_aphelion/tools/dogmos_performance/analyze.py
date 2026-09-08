"""Summarize a RIFT first-three-minute run without merging process footprints."""

import argparse
import datetime as dt
import json
import math
import re
import statistics
from pathlib import Path


def records(path):
    with path.open(encoding="utf-8-sig") as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


def summary(values):
    values = sorted(values)
    if not values:
        return None
    return dict(count=len(values), minimum=values[0], median=statistics.median(values),
                p95=values[math.ceil(0.95 * len(values)) - 1], maximum=values[-1])


def analyze(run):
    logs = run / "artifacts/data/logs/rift"
    samples = list(records(logs / "dogmos-performance.jsonl"))
    gameplay = [s for s in samples if s["shift_seconds"] is not None]
    if not gameplay:
        raise ValueError("No gameplay samples were recorded")
    begin = float(gameplay[0]["utc"]) - gameplay[0]["shift_seconds"]
    end = begin + 180
    window = [s for s in gameplay if s["shift_seconds"] <= 180]
    last_minute = [s for s in window if s["shift_seconds"] >= 120]
    resources = {}
    for event in records(run / "events.ndjson"):
        if "timestamp" not in event:
            continue
        timestamp = dt.datetime.fromisoformat(event["timestamp"].replace("Z", "+00:00")).timestamp()
        for process in event.get("data", {}).get("resource_samples", []):
            role = process.get("role", "").lower()
            if role not in ("dreamdaemon", "dogmosd"):
                continue
            phase = "gameplay" if begin <= timestamp <= end else "initialization" if timestamp < begin else None
            if phase is None:
                continue
            bucket = resources.setdefault(role, {}).setdefault(phase, {})
            for key in ("privateBytes", "workingSetBytes"):
                if key in process:
                    bucket[key] = max(bucket.get(key, 0), process[key])
    initialization = {}
    for record in records(logs / "runtime.log.json"):
        message = record.get("msg", "")
        match = re.search(r"Initialized (.+) subsystem within ([\d.]+) seconds", message)
        if match:
            initialization[match[1]] = float(match[2])
        match = re.search(r"Initializations complete within ([\d.]+) seconds", message)
        if match:
            initialization["total"] = float(match[1])
    report = json.loads((run / "summary.json").read_text(encoding="utf-8-sig"))
    return {
        "run_id": run.name,
        "rift_status": report["status"],
        "maps": sorted({s["map"] for s in gameplay}),
        "seeds": sorted({s["seed"] for s in gameplay}),
        "procedure_profiling": any(s.get("procedure_profiling", False) for s in samples),
        "complete": any(s["complete"] for s in gameplay),
        "observed_shift_seconds": gameplay[-1]["shift_seconds"],
        "initialization_seconds": initialization,
        "gameplay": {key: summary(s[key] for s in window) for key in
                     ("active_turfs", "turf_cost_ms", "groups_cost_ms", "equalize_cost_ms")},
        "last_minute_active_turfs": summary(s["active_turfs"] for s in last_minute),
        "air_cycles_observed": window[-1]["air_cycles"] - window[0]["air_cycles"],
        "process_peaks_bytes": resources,
        "active_location_samples": [dict(shift_seconds=s["shift_seconds"], locations=s["active_locations"])
                                    for s in gameplay if "active_locations" in s],
        "limits": ["Test build, fixed seed and empty player population; match controls to this workload.",
                   "The test framework creates its fixture room about ten seconds after round start.",
                   "Stage costs are rolling averages; they are not individual frame durations.",
                   "Gameplay origin is first observed playing state, within the sampler's scheduling delay."],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    result = analyze(arguments.run)
    arguments.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in result.items() if key != "active_location_samples"}, indent=2))
