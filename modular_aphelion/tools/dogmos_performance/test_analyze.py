"""Process reports must respect phase boundaries, process roles, and PID reuse."""

import tempfile
import unittest
from pathlib import Path

from analyze import dense_process_resources


class DenseProcessResourcesTest(unittest.TestCase):
    def test_phase_boundaries_and_reused_pid_do_not_merge_cpu_counters(self):
        with tempfile.TemporaryDirectory() as temporary:
            run = Path(temporary)
            (run / "processes-250ms.csv").write_text(
                "utc,role,pid,start_utc,private_bytes,working_set_bytes,virtual_bytes,cpu_seconds\n"
                "1970-01-01T00:00:09Z,dreamdaemon,1,old,10,20,30,100\n"
                "1970-01-01T00:00:10Z,dreamdaemon,1,old,11,21,31,101\n"
                "1970-01-01T00:00:10.250Z,dreamdaemon,1,old,12,22,32,101.2\n"
                "1970-01-01T00:00:10.500Z,dreamdaemon,1,new,5,6,7,0\n"
                "1970-01-01T00:00:10.750Z,dreamdaemon,1,new,6,7,8,0.1\n"
                "1970-01-01T00:00:11Z,dogmosd,2,service,5000,6000,7000,9\n"
                "1970-01-01T00:00:12Z,dreamdaemon,1,new,999,999,999,200\n",
                encoding="utf-8")
            result = dense_process_resources(run, 10, 11)
        instances = result["instances"]
        self.assertEqual(len(instances), 4)
        old_gameplay = next(item for item in instances if item["start_utc"] == "old" and item["phase"] == "gameplay")
        self.assertAlmostEqual(old_gameplay["sampled_cpu_seconds"], 0.2)
        self.assertEqual(old_gameplay["sample_gap_ms"]["maximum"], 250)
        new_gameplay = next(item for item in instances if item["start_utc"] == "new")
        self.assertEqual(new_gameplay["peaks_bytes"]["private_bytes"], 6)
        self.assertAlmostEqual(new_gameplay["sampled_cpu_seconds"], 0.1)
        service = next(item for item in instances if item["role"] == "dogmosd")
        self.assertEqual(service["peaks_bytes"]["private_bytes"], 5000)
        self.assertIsNone(service["sample_gap_ms"])

    def test_absent_dense_samples_are_explicit(self):
        with tempfile.TemporaryDirectory() as temporary:
            self.assertIsNone(dense_process_resources(Path(temporary), 10, 11))


if __name__ == "__main__":
    unittest.main()
