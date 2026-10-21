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
