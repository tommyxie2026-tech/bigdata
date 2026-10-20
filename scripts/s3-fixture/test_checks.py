import tempfile,unittest
from pathlib import Path
from checks import require_denied, exact_keys, write_report, wait_ready
class ChecksTests(unittest.TestCase):
 def test_permission_failures_must_be_actual_403_with_expected_s3_code(self):
  require_denied({"ResponseMetadata":{"HTTPStatusCode":403},"Error":{"Code":"AccessDenied"}})
  for status,code in ((200,"AccessDenied"),(404,"NoSuchKey"),(500,"InternalError"),(403,"Unexpected")):
   with self.subTest(status=status,code=code),self.assertRaises(ValueError):
    require_denied({"ResponseMetadata":{"HTTPStatusCode":status},"Error":{"Code":code}})
 def test_exact_inventory_rejects_missing_extra_and_duplicate_keys(self):
  exact_keys([{"Key":"a"}],{"a"})
  for rows in ([],[{"Key":"a"},{"Key":"b"}],[{"Key":"a"},{"Key":"a"}]):
   with self.assertRaises(ValueError):exact_keys(rows,{"a"})
 def test_missing_failed_or_skipped_check_cannot_produce_pass(self):
  with tempfile.TemporaryDirectory() as d:
   for checks in ({},{"tls":"SKIPPED"},{"tls":"FAIL"}):
    with self.assertRaises(ValueError):write_report(Path(d)/"report.json",checks,{"tls"})
   write_report(Path(d)/"report.json",{"tls":"PASS"},{"tls"})
   self.assertTrue((Path(d)/"report.json").exists())
 def test_readiness_retries_transient_errors_but_never_masks_bad_data_or_denials(self):
  class Transient(Exception):pass
  calls=[]
  def operation():
   calls.append(1)
   if len(calls)==1:raise Transient()
   return b"proof"
  self.assertEqual(wait_ready(operation,lambda e:isinstance(e,Transient),clock=lambda:0,sleep=lambda _:None),b"proof")
  self.assertEqual(len(calls),2)
  for error in (ValueError("corrupt"),PermissionError("403"),FileNotFoundError("404")):
   def fail():raise error
   with self.assertRaises(type(error)):wait_ready(fail,lambda e:isinstance(e,Transient))
  times=iter((0,181))
  def unavailable():raise Transient()
  with self.assertRaises(Transient):wait_ready(unavailable,lambda e:True,clock=lambda:next(times),sleep=lambda _:None)
if __name__=="__main__":unittest.main()
