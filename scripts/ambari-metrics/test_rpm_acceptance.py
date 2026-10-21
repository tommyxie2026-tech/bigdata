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


if __name__ == '__main__':
    unittest.main()
