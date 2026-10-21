import importlib.util
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

class S3Configuration(unittest.TestCase):
    def test_https_credentials_timeouts_and_target_are_explicit(self):
        path=Path(__file__).with_name('s3_config.py')
        spec=importlib.util.spec_from_file_location('s3_config',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        xml=module.configuration('s3a://bigdata-ci-fixture/warehouse/mysql-1')
        values={p.findtext('name'):p.findtext('value') for p in ET.fromstring(xml)}
        self.assertEqual(values['fs.s3a.endpoint'],'https://localhost:8334')
        self.assertEqual(values['fs.s3a.path.style.access'],'true')
        self.assertEqual(values['fs.s3a.connection.ssl.enabled'],'true')
        self.assertEqual(values['fs.s3a.aws.credentials.provider'],'org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider')
        self.assertEqual(values['fs.s3a.access.key'],'fixture-admin')
        self.assertEqual(values['fs.s3a.connection.timeout'],'10s')
        for invalid in ['file:///tmp/warehouse','s3a://other/warehouse/x','s3a://bigdata-ci-fixture/warehouse/../x',
                        's3a://user@bigdata-ci-fixture/warehouse/x','s3a://bigdata-ci-fixture/warehouse/x?secret=y']:
            with self.subTest(uri=invalid),self.assertRaises(ValueError):module.configuration(invalid)

    def test_fixture_trust_preserves_default_https_roots_for_maven(self):
        setup=Path(__file__).with_name('prepare-s3.sh').read_text()
        self.assertIn('-srckeystore "$JAVA_HOME/lib/security/cacerts"',setup)
        self.assertLess(setup.index('keytool -importkeystore'),setup.index('keytool -importcert'))
        self.assertLess(setup.index('keytool -importcert'),setup.index('source /workspace/'))

    def test_workflow_reuses_sdk_and_keeps_storage_separate(self):
        import yaml
        root=Path(__file__).resolve().parents[2]
        workflow=(root/'.github/workflows/cdc-paimon-s3.yml').read_text()
        config=yaml.safe_load(workflow)
        self.assertEqual(config['jobs']['test']['strategy']['matrix']['connector'],['mysql','postgres'])
        self.assertIn('39616625470',workflow)
        self.assertNotIn('bash /workspace/scripts/s3a/package-sdk.sh',workflow)
        self.assertIn('https://localhost:8334',workflow)
        self.assertIn('docker restart --time 30 cdc-storage',workflow)
        self.assertIn('assert-s3-restarted.sh',workflow)
        self.assertIn('config/server.crt:/fixture/server.crt:ro',workflow)
        client=next(step['run'] for step in config['jobs']['test']['steps'] if step.get('name')=='Clean openEuler install and exact lakehouse recovery')
        self.assertNotIn('/tmp/cdc-s3-fixture/data',client)
        self.assertNotIn('server.key',client)
        self.assertIn('build_input_identity',workflow)

if __name__=='__main__':unittest.main()
