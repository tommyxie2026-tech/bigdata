import unittest
from results import parse_phase
class ResultsTests(unittest.TestCase):
 def test_incomplete_failed_duplicate_and_wrong_phase_cannot_pass(self):
  for rows in ([],['S3A_PASS initial read'],['S3A_FAIL initial read','S3A_PASS initial write'],['S3A_PASS initial read','S3A_PASS initial read','S3A_PASS initial write'],['S3A_PASS restored read','S3A_PASS initial write']):
   with self.subTest(rows=rows),self.assertRaises(ValueError):parse_phase(rows,'initial',{'read','write'})
 def test_unrelated_output_is_not_evidence(self):
  self.assertEqual(parse_phase(['noise','S3A_PASS initial read','S3A_PASS initial write'],'initial',{'read','write'}),{'read':'PASS','write':'PASS'})

class ProvenanceTests(unittest.TestCase):
 def test_packaging_invocation_changes_are_rejected_but_test_only_changes_can_reuse(self):
  from provenance import same_packaging
  base='env:\n  SDK_REUSE_RUN: ""\njobs:\n  package:\n    name: Package optional SDK RPM\n    steps:\n      - run: package-sdk.sh\n  api:\n    steps: []\n'
  self.assertTrue(same_packaging(base,base.replace('steps: []','steps: [test-only]')))
  self.assertFalse(same_packaging(base,base.replace('run: package-sdk.sh','run: altered.sh')))
  self.assertFalse(same_packaging(base,base.replace('  package:','  renamed:')))


class ReleaseTests(unittest.TestCase):
 def test_release_requires_every_real_assertion_and_both_reports(self):
  from release import validate
  from results import INITIAL,RESTORED
  s={'status':'PASS','checks':{**{'initial.'+k:'PASS' for k in INITIAL},**{'restored.'+k:'PASS' for k in RESTORED},'s3a_multipart':'PASS'}}
  a={'status':'PASS','checks':{k:'PASS' for k in ['initial.'+k for k in ['tls_verified','crud','list_exact','multipart_complete','multipart_abort','readonly_denied','bad_key_denied','bad_secret_denied','anonymous_denied','untrusted_tls_denied','retained_object']]+['restored.'+k for k in ['tls_verified','restart_read','permissions_retained','cleanup']]}}
  validate(s,a)
  for changed in ({'status':'PASS','checks':{}},{'status':'FAIL','checks':s['checks']},{'status':'PASS','checks':dict(s['checks'],s3a_multipart='SKIPPED')}):
   with self.assertRaises(ValueError):validate(changed,a)
  with self.assertRaises(ValueError):validate(s,{'status':'PASS','checks':{}})

if __name__=='__main__':unittest.main()
