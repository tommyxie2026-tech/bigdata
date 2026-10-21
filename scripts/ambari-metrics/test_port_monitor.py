import importlib.util
from pathlib import Path
import tempfile
import unittest
import subprocess, sys, os
ROOT=Path(__file__).resolve().parent
class MonitorPortTests(unittest.TestCase):
    def load(self):
        path=ROOT/'port_monitor.py'
        self.assertTrue(path.exists(),'deterministic Python 3 port helper missing')
        spec=importlib.util.spec_from_file_location('monitor_port',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
    def test_upstream_metric_group_config_keeps_values_and_removes_only_comments(self):
        port=self.load()
        value=port.metric_groups_json('# License\n{"host_metric_groups": {"all": {"metrics": ["cpu_user", "mem_total"]}}, "literal": "#value"}\n')
        import json
        self.assertEqual(json.loads(value)['literal'],'#value')
        upstream=os.environ.get('METRICS_MONITOR_UPSTREAM_SOURCE')
        if upstream:
            conf=Path(upstream).parents[2]/'conf/unix/metric_groups.conf'
            parsed=json.loads(port.metric_groups_json(conf.read_text()))
            self.assertIn('host_metric_groups',parsed)
    def test_python2_collection_logic_runs_with_python3(self):
        port=self.load()
        source="""from Queue import Queue
values = {1: 'before', 2: 'after'}
result = [(long(k), v) for k, v in values.iteritems()]
try:
    raise ValueError('fixture')
except ValueError, error:
    message = unicode(error)
"""
        converted=port.convert_python(source,'core/fixture.py')
        scope={};exec(compile(converted,'fixture.py','exec'),scope)
        self.assertEqual(scope['result'],[(1,'before'),(2,'after')])
        self.assertEqual(scope['message'],'fixture')
    def test_thread_api_is_supported_and_vendored_psutil_bootstrap_removed(self):
        port=self.load()
        converted=port.convert_python('def running(event, thread):\n    return event.isSet() and thread.isAlive()\n','core/fixture.py')
        self.assertIn('is_set()',converted);self.assertIn('is_alive()',converted)
        converted=port.convert_python('"""License fixture."""\nimport platform, os, sys\npath="psutil/build"\nfor d in os.walk(path).next()[1]: pass\n','core/__init__.py')
        self.assertNotIn('psutil/build',converted);self.assertNotIn('sys.path',converted)
        self.assertIn('import psutil',converted)
    def test_sibling_imports_execute_as_a_python3_package(self):
        port=self.load()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source/core';out=root/'output/core'
            source.mkdir(parents=True);out.mkdir(parents=True)
            (source/'__init__.py').write_text('')
            (source/'helper.py').write_text('answer=42\n')
            original='from helper import answer\n'
            (source/'controller.py').write_text(original)
            converted=port.convert_python(original,'core/controller.py',source_filename=str(source/'controller.py'))
            (out/'__init__.py').write_text('');(out/'helper.py').write_text('answer=42\n')
            (out/'controller.py').write_text(converted)
            subprocess.run([sys.executable,'-c','from core.controller import answer; assert answer == 42'],cwd=root/'output',check=True)

    def test_main_remains_an_executable_script_with_absolute_core_import(self):
        port=self.load()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source';out=root/'output'
            (source/'core').mkdir(parents=True);(out/'core').mkdir(parents=True)
            (source/'__init__.py').write_text('');(source/'core/__init__.py').write_text('')
            (source/'core/helper.py').write_text('answer=42\n')
            original='from core.helper import answer\nassert answer == 42\n'
            (source/'main.py').write_text(original)
            converted=port.convert_python(original,'main.py',source_filename=str(source/'main.py'))
            (out/'main.py').write_text(converted)
            (out/'core/__init__.py').write_text('');(out/'core/helper.py').write_text('answer=42\n')
            subprocess.run([sys.executable,str(out/'main.py')],cwd=out,check=True)

    def test_pid_paths_match_the_monitor_service_directory(self):
        port=self.load()
        source="import os\nPID_DIR=os.path.join(os.sep, 'var', 'run', 'ambari-metrics-host-monitoring')\nPID_OUT_FILE=PID_DIR+'/ambari-metrics-host-monitoring.pid'\n"
        converted=port.convert_python(source,'core/config_reader.py')
        scope={};exec(converted,scope)
        self.assertEqual(scope['PID_DIR'],'/var/run/ambari-metrics-monitor')
        self.assertEqual(scope['PID_OUT_FILE'],'/var/run/ambari-metrics-monitor/ambari-metrics-monitor.pid')

    def test_upstream_minute_buckets_keep_all_unfinished_minute_points(self):
        location=os.environ.get('METRICS_MONITOR_UPSTREAM_SOURCE')
        if not location:self.skipTest('requires pinned upstream source supplied by live CI')
        port=self.load();path=Path(location)/'core/application_metric_map.py'
        scope={};exec(port.convert_python(path.read_text(),'core/application_metric_map.py',source_filename=str(path)),scope)
        metrics=scope['ApplicationMetricMap']('host-ci','127.0.0.1')
        result=metrics.align_values_by_minute_mark('HOST','cpu_user',{15000:1,59000:2,60000:3,75000:4})
        self.assertEqual(result,{15000:1,59000:2})
        self.assertEqual(metrics.cached_metric_map['HOST']['cpu_user'],{60000:3,75000:4})
        result=metrics.align_values_by_minute_mark('HOST','cpu_user',{85000:5,175000:6})
        self.assertEqual(result,{60000:3,75000:4,85000:5,175000:6})

    def test_port_preserves_source_and_emits_only_owned_python_with_hashes(self):
        port=self.load()
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);source=root/'source';out=root/'output'
            (source/'core').mkdir(parents=True);(source/'psutil').mkdir()
            (source/'main.py').write_text('print "monitor"\n')
            (source/'core/__init__.py').write_text('import platform, os, sys\n')
            (source/'psutil/setup.py').write_text('raise RuntimeError("must not be copied")\n')
            manifest=port.port_tree(source,out)
            self.assertEqual((source/'main.py').read_text(),'print "monitor"\n')
            self.assertFalse((out/'psutil').exists())
            self.assertEqual(set(manifest),{'main.py','core/__init__.py'})
            self.assertNotEqual(manifest['main.py']['source_sha256'],manifest['main.py']['ported_sha256'])
            compile((out/'main.py').read_text(),'main.py','exec')
if __name__=='__main__':unittest.main()
