import unittest
from protocol import savepoint_location, verify_restored

class ProtocolTests(unittest.TestCase):
    def test_completed_savepoint_has_location(self):
        self.assertEqual(savepoint_location({"status":{"id":"COMPLETED"},
            "operation":{"location":"file:///state/savepoint-abc"}}), "file:///state/savepoint-abc")
    def test_pending_failed_and_missing_location_are_not_success(self):
        for response in ({"status":{"id":"IN_PROGRESS"}},
                         {"status":{"id":"COMPLETED"},"operation":{"failure-cause":{"message":"bad"}}},
                         {"status":{"id":"COMPLETED"},"operation":{}}):
            with self.subTest(response=response), self.assertRaises(ValueError):
                savepoint_location(response)
    def test_restoration_must_reference_the_exact_savepoint(self):
        path = "file:///state/savepoint-abc"
        verify_restored({"latest":{"restored":{"external_path":path,"is_savepoint":True}}}, path)
        for info in ({}, {"latest":{"restored":{"external_path":"file:///other","is_savepoint":True}}},
                     {"latest":{"restored":{"external_path":path,"is_savepoint":False}}}):
            with self.subTest(info=info), self.assertRaises(ValueError):
                verify_restored(info, path)

if __name__ == "__main__":
    unittest.main()
