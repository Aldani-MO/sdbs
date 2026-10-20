"""
offline_queue.py — SQLite Offline Queue (AI-05)

When the network is down and Firebase upload fails,
records are stored locally and retried automatically.
"""

import sqlite3
import json
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "offline_queue.db")


class OfflineQueue:
    def __init__(self):
        self.conn = sqlite3.connect(DB_PATH)
        self._create_table()

    def _create_table(self):
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS pending_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                payload TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        self.conn.commit()

    def enqueue(self, record: dict):
        """Save a failed upload record for later retry."""
        self.conn.execute(
            "INSERT INTO pending_records (payload) VALUES (?)",
            (json.dumps(record),)
        )
        self.conn.commit()
        count = self.pending_count()
        print(f"[QUEUE] Record saved offline. Pending: {count}")

    def dequeue_all(self):
        """Get all pending records and their IDs."""
        cursor = self.conn.execute("SELECT id, payload FROM pending_records ORDER BY id")
        rows = cursor.fetchall()
        return [(row[0], json.loads(row[1])) for row in rows]

    def remove(self, record_id: int):
        """Remove a successfully uploaded record from the queue."""
        self.conn.execute("DELETE FROM pending_records WHERE id = ?", (record_id,))
        self.conn.commit()

    def pending_count(self):
        cursor = self.conn.execute("SELECT COUNT(*) FROM pending_records")
        return cursor.fetchone()[0]

    def close(self):
        self.conn.close()
