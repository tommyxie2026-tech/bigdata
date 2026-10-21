import importlib.util
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parent
class MonitorPayloadTests(unittest.TestCase):
    def load(self):
        path=ROOT/'verify_monitor_payload.py'
        self.assertTrue(path.exists(),'real host metric validator missing')
        spec=importlib.util.spec_from_file_location('monitor_payload',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
    def payload(self):
        return {'metrics':[{'metricname':name,'hostname':'host-ci','metrics':{'1792599000000':value}} for name,value in [('cpu_user',12.5),('mem_total',2048)]]}
    def test_fresh_real_cpu_and_memory_are_required(self):
        validator=self.load();data=self.payload()
        self.assertEqual(validator.host_samples(data,1792599001000,1792598999000),{'cpu_user','mem_total'})
        data['metrics']=data['metrics'][:1]
        self.assertNotEqual(validator.host_samples(data,1792599001000,1792598999000),{'cpu_user','mem_total'})
    def test_stale_future_empty_hostname_or_invalid_values_are_rejected(self):
        validator=self.load()
        for change in ['stale','future','empty-host','nan','negative-memory','cpu-out-of-range']:
            data=self.payload()
            if change=='stale': data['metrics'][0]['metrics']={'1792590000000':12.5}
            if change=='future': data['metrics'][0]['metrics']={'1792690000000':12.5}
            if change=='empty-host': data['metrics'][0]['hostname']=''
            if change=='nan': data['metrics'][0]['metrics']={'1792599000000':float('nan')}
            if change=='negative-memory': data['metrics'][1]['metrics']={'1792599000000':-1}
            if change=='cpu-out-of-range': data['metrics'][0]['metrics']={'1792599000000':101}
            with self.subTest(change=change):
                self.assertNotEqual(validator.host_samples(data,1792599001000,1792598999000),{'cpu_user','mem_total'})
if __name__=='__main__':unittest.main()
