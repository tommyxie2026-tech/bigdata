import os
from pathlib import Path
import subprocess
import unittest
import yaml
ROOT=Path(__file__).resolve().parents[2]

class IcebergRecoveryContract(unittest.TestCase):
    def test_java_runtime_keeps_existing_targets_and_opens_java17_modules(self):
        runtime=ROOT/'scripts/cdc-lakehouse/java-runtime.sh'
        for target in ['jdbc','paimon','hudi','iceberg']:
            env={**os.environ,'CDC_TARGET':target,'JAVA_TOOL_OPTIONS':'-Dfixture=preserved'}
            result=subprocess.check_output(['bash','-c','source "$1"; printf "%s\\n%s" "$CDC_JDK" "$JAVA_TOOL_OPTIONS"','test',str(runtime)],env=env,text=True)
            jdk,options=result.split('\n',1)
            self.assertEqual(jdk,'17' if target=='iceberg' else '11')
            self.assertIn('-Dfixture=preserved',options)
            self.assertEqual('--add-opens=java.base/java.util=ALL-UNNAMED' in options,target=='iceberg')
        for connector in ['mysql','postgres']:
            script=(ROOT/f'scripts/flink-cdc-{connector}/test.sh').read_text()
            self.assertLess(script.index('source /workspace/scripts/cdc-lakehouse/java-runtime.sh'),script.index('dnf -y'))
            self.assertIn('"java-$CDC_JDK-openjdk-devel"',script)
            self.assertIn('jdk: $CDC_JDK',script)
    def test_real_iceberg_upsert_and_remote_recovery_are_required(self):
        workflow=(ROOT/'.github/workflows/cdc-iceberg-hdfs.yml').read_text()
        config=yaml.safe_load(workflow)
        self.assertEqual(config['jobs']['test']['strategy']['matrix']['connector'],['mysql','postgres'])
        self.assertIn('iceberg/1.12.0/',workflow)
        self.assertIn('CDC_TARGET: iceberg',workflow)
        self.assertIn('jdk17-v1-',workflow)
        self.assertIn('assert-iceberg-restarted.sh',workflow)
        source=(ROOT/'scripts/cdc-lakehouse/IcebergTarget.java').read_text()
        for marker in ["'type'='iceberg'","'catalog-type'='hadoop'","'format-version'='2'",
                       "'write.upsert.enabled'='true'",'actual.equals(expected)','Duplicate key','iceberg: PASS exact_rows=']:
            self.assertIn(marker,source)
        prepare=(ROOT/'scripts/cdc-lakehouse/prepare-target.sh').read_text()
        self.assertIn('bigdata-iceberg-flink hadoop-client',prepare)
        self.assertIn('source_identity: 212aa894e919ff9fdf89160da4aadcbe6858ac01',prepare)

if __name__=='__main__':unittest.main()
