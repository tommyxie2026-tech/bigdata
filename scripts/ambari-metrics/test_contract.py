import unittest
from pathlib import Path
import json,yaml
ROOT=Path(__file__).resolve().parents[2]
class MetricsSourceContract(unittest.TestCase):
    def test_metrics_uses_its_own_immutable_upstream(self):
        path=ROOT/'scripts/ambari-metrics/contract.json'
        self.assertTrue(path.exists(),'independent Metrics contract missing')
        spec=json.loads(path.read_text())
        self.assertEqual(spec['repository'],'apache/ambari-metrics')
        self.assertEqual(spec['source_identity'],'ce919386e963841ea37f032c5ba6ed9c48298dd8')
        self.assertEqual(spec['version'],'3.0.0')
        self.assertEqual(spec['runtime_packages'],['ambari-metrics-collector','ambari-metrics-monitor'])
    def test_source_build_checks_actual_collector_entrypoint_and_caches_dependencies(self):
        path=ROOT/'scripts/ambari-metrics/build-source.sh'
        self.assertTrue(path.exists(),'Metrics source build missing')
        source=path.read_text()
        for marker in ['retry-maven-downloads.sh','org/apache/ambari/metrics/AMSApplicationServer.class','sha256sum','-P!linux','MAVEN_RETRY_TOTAL_SECONDS']:
            self.assertIn(marker,source)
        self.assertNotIn('mvn clean',source)
        self.assertIn('cp LICENSE.txt /work/output/',source)
        self.assertNotIn('cp LICENSE NOTICE',source)
        self.assertIn('git config --global --add safe.directory /source',source)
    def test_source_workflow_tracks_only_effective_source_inputs(self):
        import fnmatch
        config=yaml.load((ROOT/'.github/workflows/ambari-metrics.yml').read_text(),Loader=yaml.BaseLoader)
        inputs=['scripts/ambari-metrics/build-source.sh','scripts/ambari-metrics/contract.json',
                'scripts/ambari-metrics/test_contract.py','scripts/ci/retry-maven-downloads.sh',
                'scripts/ci/configure-maven-policy.py','scripts/ci/run-with-deadline.py',
                '.github/actions/restore-build-dependencies/action.yml',
                '.github/actions/save-build-dependencies/action.yml']
        unrelated=['scripts/ambari-metrics/specs/collector.spec',
                   'scripts/ambari-metrics/package-rpms.sh','scripts/ambari-metrics/port_monitor.py',
                   'scripts/ambari-metrics/test_monitor_payload.py']
        for event in ['pull_request','push']:
            patterns=config['on'][event]['paths']
            for path in inputs:
                self.assertTrue(any(fnmatch.fnmatchcase(path,p) for p in patterns),(event,path))
            for path in unrelated:
                self.assertFalse(any(fnmatch.fnmatchcase(path,p) for p in patterns),(event,path))

    def test_workflow_restores_and_saves_downloads_on_failure(self):
        path=ROOT/'.github/workflows/ambari-metrics.yml'
        self.assertTrue(path.exists(),'independent Metrics CI missing')
        source=path.read_text()
        config=yaml.safe_load(source)
        self.assertIn('source',config['jobs'])
        self.assertIn('./.github/actions/restore-build-dependencies',source)
        self.assertIn('./.github/actions/save-build-dependencies',source)
        self.assertIn('if: always()',source)
if __name__=='__main__':unittest.main()
