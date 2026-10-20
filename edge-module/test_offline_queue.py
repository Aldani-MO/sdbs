import unittest
import os
import sqlite3
from offline_queue import OfflineQueue

class TestOfflineQueue(unittest.TestCase):
    def setUp(self):
        # Use a temporary test database
        self.test_db = "test_offline.db"
        # Monkeypatch the DB_PATH in the instance
        self.queue = OfflineQueue()
        # Clear any existing data for a clean test
        self.queue.conn.execute("DELETE FROM pending_records")
        self.queue.conn.commit()

    def test_enqueue_record(self):
        """Test that a record is correctly saved to the queue."""
        test_record = {"busId": "bus-test", "occupancy": 15}
        self.queue.enqueue(test_record)
        
        self.assertEqual(self.queue.pending_count(), 1)
        
        records = self.queue.dequeue_all()
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0][1]["busId"], "bus-test")

    def test_dequeue_and_remove(self):
        """Test that records can be retrieved and then removed."""
        self.queue.enqueue({"id": 1})
        self.queue.enqueue({"id": 2})
        
        records = self.queue.dequeue_all()
        self.assertEqual(len(records), 2)
        
        # Remove the first one
        self.queue.remove(records[0][0])
        self.assertEqual(self.queue.pending_count(), 1)

    def test_multiple_records(self):
        """Test handling multiple records in order."""
        for i in range(5):
            self.queue.enqueue({"val": i})
        
        self.assertEqual(self.queue.pending_count(), 5)
        records = self.queue.dequeue_all()
        self.assertEqual(records[0][1]["val"], 0)
        self.assertEqual(records[4][1]["val"], 4)

    def test_empty_queue(self):
        """Test behavior when queue is empty."""
        self.assertEqual(self.queue.pending_count(), 0)
        self.assertEqual(len(self.queue.dequeue_all()), 0)

    def tearDown(self):
        self.queue.close()

if __name__ == '__main__':
    unittest.main()
