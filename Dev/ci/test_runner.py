import os
from pathlib import Path
import subprocess
import tempfile
import unittest


RUNNER = Path(__file__).with_name("test.sh")


class RunnerTests(unittest.TestCase):
    def run_fake(self, body, args=()):
        with tempfile.TemporaryDirectory() as directory:
            fake = Path(directory) / "luajit"
            fake.write_text("#!/usr/bin/env bash\nset -euo pipefail\n" + body)
            fake.chmod(0o755)
            log = Path(directory) / "calls"
            result = subprocess.run(["bash", str(RUNNER), *args], capture_output=True, text=True,
                                    env=dict(os.environ, LUAJIT=str(fake), RUNNER_LOG=str(log)))
            calls = log.read_text().splitlines() if log.exists() else []
            return result, calls

    def test_each_registered_file_gets_its_own_process_and_locale(self):
        result, calls = self.run_fake('''
if [[ "$2" == --list ]]; then printf 'identity\\nlocale\\n'; exit; fi
printf '%s\\n' "$*" >> "$RUNNER_LOG"
''', ("--locale", "deDE"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, ["tests/run.lua identity.lua --locale deDE", "tests/run.lua locale.lua --locale deDE"])

    def test_enumerator_failure_stops_before_running_any_file(self):
        result, calls = self.run_fake('printf "identity\\n"; exit 7\n')
        self.assertEqual(result.returncode, 7)
        self.assertEqual(calls, [])

    def test_test_failure_stops_the_gate(self):
        result, calls = self.run_fake('''
if [[ "$2" == --list ]]; then printf 'identity\\nlocale\\n'; exit; fi
printf '%s\\n' "$2" >> "$RUNNER_LOG"
exit 9
''')
        self.assertEqual(result.returncode, 9)
        self.assertEqual(calls, ["identity.lua"])

    def test_empty_registry_is_not_success(self):
        result, _ = self.run_fake("exit 0\n")
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
