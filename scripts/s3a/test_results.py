import unittest
from results import parse_phase
class ResultsTests(unittest.TestCase):
 def test_incomplete_failed_duplicate_and_wrong_phase_cannot_pass(self):
  for rows in ([],['S3A_PASS initial read'],['S3A_FAIL initial read','S3A_PASS initial write'],['S3A_PASS initial read','S3A_PASS initial read','S3A_PASS initial write'],['S3A_PASS restored read','S3A_PASS initial write']):
   with self.subTest(rows=rows),self.assertRaises(ValueError):parse_phase(rows,'initial',{'read','write'})
 def test_unrelated_output_is_not_evidence(self):
  self.assertEqual(parse_phase(['noise','S3A_PASS initial read','S3A_PASS initial write'],'initial',{'read','write'}),{'read':'PASS','write':'PASS'})
if __name__=='__main__':unittest.main()
