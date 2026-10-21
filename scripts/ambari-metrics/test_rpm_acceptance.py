import importlib.util
import unittest
from pathlib import Path


class CollectorAcceptanceTests(unittest.TestCase):
    def load(self):
        spec = importlib.util.spec_from_file_location('acceptance', Path(__file__).with_name('verify_collector.py'))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_only_real_host_fresh_finite_metrics_are_accepted(self):
        module = self.load()
        payload = {'metrics': [
            {'metricname': 'cpu_user', 'hostname': 'host', 'appid': 'HOST', 'metrics': {'100000': 12}},
            {'metricname': 'mem_total', 'hostname': 'host', 'appid': 'HOST', 'metrics': {'100000': 8192}}]}
        self.assertEqual(set(module.samples(payload, 'host', 90000, 110000)), {'cpu_user', 'mem_total'})
        for field, value in [('hostname', 'other'), ('appid', 'other'), ('metrics', {'80000': 3}),
                             ('metrics', {'120000': 3}), ('metrics', {'100000': float('nan')})]:
            bad = {'metrics': [dict(payload['metrics'][0], **{field: value}), payload['metrics'][1]]}
            self.assertNotEqual(set(module.samples(bad, 'host', 90000, 110000)), {'cpu_user', 'mem_total'})

    def test_restart_requires_identical_historical_values(self):
        module = self.load()
        before = {'cpu_user': {'100000': 12}, 'mem_total': {'100000': 8192}}
        module.assert_persisted(before, dict(before, cpu_user={'100000': 12, '110000': 15}))
        for after in [{}, dict(before, cpu_user={}), dict(before, cpu_user={'100000': 13})]:
            with self.assertRaises(AssertionError):
                module.assert_persisted(before, after)

    def test_portable_compression_preserves_other_runtime_settings(self):
        import json,runpy,sys,tempfile,types
        from unittest.mock import patch
        import xml.etree.ElementTree as ET
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);collector=root/'collector';monitor=root/'monitor'
            for relative in ['etc/ams-hbase/conf/hbase-site.xml',
                             'etc/ambari-metrics-collector/conf/hbase-site.xml',
                             'etc/ambari-metrics-collector/conf/ams-site.xml']:
                path=collector/relative;path.parent.mkdir(parents=True,exist_ok=True)
                path.write_text('<configuration><property><name>keep.me</name><value>kept</value></property>'
                    '<property><name>timeline.metrics.hbase.compression.scheme</name><value>SNAPPY</value></property></configuration>')
            conf=monitor/'etc/ambari-metrics-monitor/conf';conf.mkdir(parents=True)
            (conf/'metric_monitor.ini').write_text('[default]\n[collector]\n')
            groups=root/'groups';groups.write_text('{"host_metric_groups":{}}')
            fake=types.ModuleType('port_monitor');fake.metric_groups_json=lambda text:json.dumps(json.loads(text))
            script=Path(__file__).with_name('prepare-rpm-config.py')
            with patch.dict(sys.modules,{'port_monitor':fake}),patch.object(sys,'argv',[str(script),str(collector),str(monitor),str(groups)]):
                runpy.run_path(str(script),run_name='__main__')
            path=collector/'etc/ambari-metrics-collector/conf/ams-site.xml'
            values={p.findtext('name'):p.findtext('value') for p in ET.parse(path).getroot()}
            self.assertEqual(values['timeline.metrics.hbase.compression.scheme'],'GZ')
            self.assertEqual(values['keep.me'],'kept')
            self.assertNotIn('hbase.table.sanity.checks',values)


if __name__ == '__main__':
    unittest.main()
