#!/usr/bin/env python3
"""Exercise the Paimon result parser with actual Spark output and negative cases."""
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "scripts/ci/test-paimon-rpm-openeuler-container.sh"

class ResultParserTests(unittest.TestCase):
    def check_result(self, log, expected="1:1"):
        source = SOURCE.read_text()
        start = source.index("assert_result_row()")
        end = source.index('\n: "${COMPONENT', start)
        helper = source[start:end]
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "query.log"
            path.write_text(log)
            return subprocess.run(
                ["bash", "-c", helper + '\nassert_result_row "$1" "$2"', "_", str(path), expected],
                capture_output=True, text=True,
            ).returncode

    def test_real_spark_plain_output(self):
        self.assertEqual(self.check_result(
            'Time taken: 0.26 seconds\n1:1\nTime taken: 0.459 seconds, Fetched 1 row(s)\n'
        ), 0)

    def test_formatted_output(self):
        for log, expected in [
            ("| 1:1 |\n", "1:1"),
            ("| 1 | spark-after |\n", "1:spark-after"),
        ]:
            with self.subTest(log=log):
                self.assertEqual(self.check_result(log, expected), 0)

    def test_wrong_results_and_sql_echo_fail(self):
        for log in [
            "0:0\n", "| 2:1 |\n", "SELECT '1:1';\n",
            "WARN expected 1:1\n", "", "| 1:1 | extra |\n",
        ]:
            with self.subTest(log=log):
                self.assertNotEqual(self.check_result(log), 0)

if __name__ == "__main__":
    unittest.main(verbosity=2)
