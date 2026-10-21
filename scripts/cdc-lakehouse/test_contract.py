import unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[2]
class LakehouseContract(unittest.TestCase):
    def test_both_connectors_use_real_paimon_sink_and_exact_reader(self):
        for component,klass in [('mysql','MysqlSmoke'),('postgres','PostgresSmoke')]:
            source=(ROOT/f'scripts/flink-cdc-{component}/harness/src/main/java/bigdata/ci/{klass}.java').read_text()
            self.assertIn('PaimonTarget.enabled()',source)
            self.assertIn('PaimonTarget.assertRows(expected)',source)
            self.assertIn(f'PaimonTarget.submit(table, "{component}_source")',source)
    def test_paimon_uses_committed_batch_read_and_checkpoint_sink(self):
        path=ROOT/'scripts/cdc-lakehouse/PaimonTarget.java'
        self.assertTrue(path.exists(),'real Paimon target helper missing')
        source=path.read_text()
        self.assertIn('CREATE CATALOG lakehouse',source)
        self.assertIn('CREATE DATABASE IF NOT EXISTS lakehouse.cdc_ci',source)
        self.assertNotIn('lakehouse.default.',source)
        self.assertIn('CREATE TABLE IF NOT EXISTS lakehouse.cdc_ci.lake_rows',source)
        self.assertNotIn('CREATE TEMPORARY TABLE lake_rows',source)
        for marker in ['EnvironmentSettings.inBatchMode()',"'type'='paimon'",'INSERT INTO lakehouse.cdc_ci.lake_rows SELECT','rows.collect()','actual.equals(expected)','Duplicate key']:
            self.assertIn(marker,source)
    def test_independent_workflow_runs_both_without_build_or_publication(self):
        path=ROOT/'.github/workflows/cdc-paimon.yml'
        self.assertTrue(path.exists(),'lakehouse integration workflow missing')
        config=yaml.safe_load(path.read_text())
        self.assertEqual(config['jobs']['test']['strategy']['matrix']['connector'],['mysql','postgres'])
        self.assertEqual(set(config['jobs']),{'test'})
        self.assertIn('CDC_TARGET: paimon',path.read_text())
    def test_existing_recovery_test_enables_target_before_harness_compile(self):
        for name in ['mysql','postgres']:
            source=(ROOT/f'scripts/flink-cdc-{name}/test.sh').read_text()
            self.assertIn('scripts/cdc-lakehouse/prepare-target.sh',source)
            self.assertLess(source.index('scripts/cdc-lakehouse/prepare-target.sh'),source.index('mvn -B'))
            self.assertIn('fixture assert restored',source)
            self.assertIn('protocol.py restored',source)
if __name__=='__main__':unittest.main()
