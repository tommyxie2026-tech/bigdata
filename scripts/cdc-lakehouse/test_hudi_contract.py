import unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[2]

class HudiRecoveryContract(unittest.TestCase):
    def test_published_hudi_runtime_and_exact_recovery_are_required(self):
        workflow=(ROOT/'.github/workflows/cdc-hudi-hdfs.yml').read_text()
        config=yaml.safe_load(workflow)
        self.assertEqual(config['jobs']['test']['strategy']['matrix']['connector'],['mysql','postgres'])
        self.assertEqual(set(config['jobs']),{'test'})
        self.assertIn('hudi/1.2.1/',workflow)
        self.assertNotIn('paimon/2.1.0',workflow)
        self.assertIn('CDC_TARGET: hudi',workflow)
        self.assertIn('assert-hudi-restarted.sh',workflow)
        self.assertIn('docker restart --time 30 cdc-storage',workflow)
        prepare=(ROOT/'scripts/cdc-lakehouse/prepare-target.sh').read_text()
        self.assertIn('bigdata-hudi-flink hadoop-client',prepare)
        self.assertIn('source_identity: a9185b7c4e83422132c25f2efdf282c5bc6af2c7',prepare)
        self.assertIn('hudi-flink1.20-bundle-1.2.1.jar',prepare)
    def test_hudi_replays_database_order_and_reads_real_commits(self):
        source=(ROOT/'scripts/cdc-lakehouse/HudiTarget.java').read_text()
        for marker in ["'connector'='hudi'","'table.type'='COPY_ON_WRITE'",
                       "'write.operation'='upsert'","'hoodie.write.record.merge.mode'='COMMIT_TIME_ORDERING'",
                       'WarehouseLocation.configured()', 'EnvironmentSettings.inBatchMode()',
                       'actual.equals(expected)', 'Duplicate key', 'hudi: PASS exact_rows=']:
            self.assertIn(marker,source)
        self.assertNotIn('jdbc:',source)
        dispatcher=(ROOT/'scripts/cdc-lakehouse/LakehouseTarget.java').read_text()
        for target in ['HudiTarget','PaimonTarget']:
            self.assertIn(target+'.submit(table, source)',dispatcher)
            self.assertIn(target+'.assertRows(expected)',dispatcher)

if __name__=='__main__':unittest.main()
