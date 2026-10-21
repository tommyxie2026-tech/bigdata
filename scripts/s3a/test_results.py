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

if __name__=='__main__':unittest.main()
