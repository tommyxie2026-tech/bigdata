#!/usr/bin/env python3
"""Exercise retry decisions, deadlines, offline settings and workflow cache wiring."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / 'scripts/ci'


class DependencyPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def retry(self, body, **overrides):
        command = self.root / 'command.sh'
        command.write_text('set -eu\n' + body)
        env = dict(os.environ, MAVEN_RETRY_DELAY_SECONDS='0',
                   CI_MAVEN_SETTINGS_FILE=str(self.root / 'settings.xml'),
                   MAVEN_NETWORK_MODE='online', MAVEN_MIRROR_URL='')
        env.update(overrides)
        return subprocess.run(['bash', str(SCRIPTS / 'retry-maven-downloads.sh'),
                               str(self.root / 'build.log'), 'bash', str(command)],
                              env=env, capture_output=True, text=True, timeout=15)

    def test_compile_error_is_not_retried(self):
        result = self.retry('echo attempt >> "$COUNT_FILE"\necho "[ERROR] compilation failure"\nexit 7\n',
                            COUNT_FILE=str(self.root / 'count'))
        self.assertEqual(result.returncode, 7, result.stderr)
        self.assertEqual((self.root / 'count').read_text().splitlines(), ['attempt'])

    def test_missing_artifact_is_not_retried(self):
        result = self.retry('echo attempt >> "$COUNT_FILE"\necho "[ERROR] Could not transfer artifact x: 404 Not Found"\nexit 1\n',
                            COUNT_FILE=str(self.root / 'count'))
        self.assertEqual(result.returncode, 1)
        self.assertEqual((self.root / 'count').read_text().splitlines(), ['attempt'])

    def test_connection_reset_retries_and_preserves_cache(self):
        marker = self.root / 'downloaded.jar'
        marker.write_text('cached bytes')
        result = self.retry('if [ ! -f "$COUNT_FILE" ]; then\n touch "$COUNT_FILE"\n echo "[ERROR] Could not transfer artifact x: Connection reset"\n exit 1\nfi\n',
                            COUNT_FILE=str(self.root / 'count'))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(marker.read_text(), 'cached bytes')
        self.assertIn('attempt=2', result.stdout)

    def test_hung_command_is_killed_without_retry(self):
        result = self.retry('echo attempt >> "$COUNT_FILE"\nsleep 30\n',
                            COUNT_FILE=str(self.root / 'count'),
                            MAVEN_RETRY_ATTEMPT_SECONDS='1', MAVEN_RETRY_TOTAL_SECONDS='3')
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertEqual((self.root / 'count').read_text().splitlines(), ['attempt'])
        self.assertIn('timeout', result.stdout.lower())

    def test_total_budget_includes_backoff(self):
        result = self.retry('echo attempt >> "$COUNT_FILE"\necho "[ERROR] Could not transfer artifact x: Connection reset"\nexit 1\n',
                            COUNT_FILE=str(self.root / 'count'), MAVEN_RETRY_TOTAL_SECONDS='1',
                            MAVEN_RETRY_DELAY_SECONDS='10')
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertEqual((self.root / 'count').read_text().splitlines(), ['attempt'])

    def test_new_invocation_does_not_append_old_errors(self):
        (self.root / 'build.log').write_text('OLD FAILURE\n')
        result = self.retry('echo current\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('OLD FAILURE', (self.root / 'build.log').read_text())

    def test_mirror_and_offline_preserve_server_credentials(self):
        settings = self.root / 'settings.xml'
        settings.write_text('<settings><servers><server><id>ci-dependency-mirror</id>'
                            '<password>secret</password></server></servers></settings>')
        env = dict(os.environ, MAVEN_MIRROR_URL='https://maven.example/repo?a=1&b=2',
                   MAVEN_NETWORK_MODE='offline')
        result = subprocess.run([sys.executable, str(SCRIPTS / 'configure-maven-policy.py'),
                                 '--settings-file', str(settings)], env=env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        tree = ET.parse(settings)
        self.assertEqual(tree.findtext('offline'), 'true')
        self.assertEqual(tree.findtext('mirrors/mirror/url'), env['MAVEN_MIRROR_URL'])
        self.assertEqual(tree.findtext('servers/server/password'), 'secret')
        self.assertNotIn('secret', result.stdout + result.stderr)

    def test_offline_failure_never_retries(self):
        result = self.retry('echo attempt >> "$COUNT_FILE"\necho "[ERROR] Could not transfer artifact x: Connection reset"\nexit 1\n',
                            COUNT_FILE=str(self.root / 'count'), MAVEN_NETWORK_MODE='offline')
        self.assertEqual(result.returncode, 1)
        self.assertEqual((self.root / 'count').read_text().splitlines(), ['attempt'])

    def test_invalid_mirror_preserves_existing_settings(self):
        settings = self.root / 'settings.xml'
        settings.write_text('<settings/>')
        result = self.retry('touch "$COUNT_FILE"\n', COUNT_FILE=str(self.root / 'count'),
                            MAVEN_MIRROR_URL='https://user:secret@example.invalid/repo')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(settings.read_text(), '<settings/>')
        self.assertNotIn('secret', result.stderr)
        self.assertFalse((self.root / 'count').exists())

    def test_gradle_offline_flag_is_forwarded(self):
        command = self.root / 'gradlew'
        command.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$@" > "$ARGS_FILE"\n')
        command.chmod(0o755)
        env = dict(os.environ, MAVEN_NETWORK_MODE='offline', MAVEN_MIRROR_URL='',
                   CI_MAVEN_SETTINGS_FILE=str(self.root / 'settings.xml'),
                   ARGS_FILE=str(self.root / 'args'))
        result = subprocess.run(['bash', str(SCRIPTS / 'retry-maven-downloads.sh'),
                                 str(self.root / 'build.log'), str(command), 'package'],
                                env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'args').read_text().splitlines(), ['--offline', 'package'])

    def test_invalid_mode_does_not_start_build(self):
        result = self.retry('touch "$COUNT_FILE"\n', COUNT_FILE=str(self.root / 'count'),
                            MAVEN_NETWORK_MODE='typo')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'count').exists())


if __name__ == '__main__':
    unittest.main()
