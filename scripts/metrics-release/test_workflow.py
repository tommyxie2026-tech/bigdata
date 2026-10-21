import unittest
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[2]

class ReleaseWorkflow(unittest.TestCase):
    def test_publication_is_manual_main_only_and_evidence_gated(self):
        workflow=yaml.safe_load((ROOT/'.github/workflows/ambari-metrics-release.yml').read_text())
        events=workflow.get('on',workflow.get(True))
        self.assertEqual(set(events),{'pull_request','workflow_dispatch'})
        self.assertEqual(set(events['workflow_dispatch']['inputs']),{'package_run_id','test_run_id'})
        release=workflow['jobs']['candidate']
        self.assertIn("github.event_name == 'workflow_dispatch'",release['if'])
        self.assertIn("github.ref == 'refs/heads/main'",release['if'])
        steps=release['steps']
        commands=[step.get('run','') for step in steps]
        self.assertTrue(any('scripts/metrics-release/assemble.py' in command for command in commands))
        assembly=next(i for i,s in enumerate(steps) if 'assemble.py' in s.get('run',''))
        upload=next(i for i,s in enumerate(steps) if s.get('uses','').startswith('actions/upload-artifact'))
        self.assertLess(assembly,upload)
        promote=workflow['jobs']['promote']
        self.assertEqual(promote['needs'],'candidate')
        self.assertIn("needs.candidate.result == 'success'",promote['if'])
        self.assertNotIn('gh pr merge','\n'.join(commands))

if __name__=='__main__':unittest.main()
