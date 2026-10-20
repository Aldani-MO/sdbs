"""
uploader.py — Firebase Firestore Uploader (AI-04)

Uploads OccupancyRecord to Firestore using Firebase Admin SDK.
Falls back to offline SQLite queue on network failure.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timezone
from offline_queue import OfflineQueue
from config import SERVICE_ACCOUNT_PATH, BUS_ID


class FirebaseUploader:
    def __init__(self):
        # Initialize Firebase Admin SDK with service account
        if not firebase_admin._apps:
            cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
            firebase_admin.initialize_app(cred)

        self.db = firestore.client()
        self.queue = OfflineQueue()
        self.upload_count = 0
        self.last_uploaded_count = -1  # Track last count to prevent spam

        print(f"[FIREBASE] Connected. Bus ID: {BUS_ID}")

    def upload_record(self, count: int, confidence: float, is_valid: bool):
        """
        Upload an OccupancyRecord to Firestore.
        Optimized: Only uploads if the count has changed to save database costs
        """
        if count == self.last_uploaded_count:
            return

        record = {
            "busId": BUS_ID,
            "count": count,
            "confidence": round(confidence, 3),
            "isValid": is_valid,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        try:
            self.db.collection("occupancyRecords").add(record)
            self.upload_count += 1
            self.last_uploaded_count = count
            print(f"[UPLOAD #{self.upload_count}] People count changed to: {count} | Conf: {confidence:.2f} | Valid: {is_valid}")

            self.db.collection("buses").document(BUS_ID).set({
                "currentOccupancy": count,
                "capacity": 50,  # Ensure capacity is recorded in Firestore
                "lastUpdated": firestore.SERVER_TIMESTAMP,
            }, merge=True)

            self._flush_queue()

        except Exception as e:
            print(f"[UPLOAD FAILED] {e}")
            self.queue.enqueue(record)

    def _flush_queue(self):
        """Try to upload all pending offline records."""
        pending = self.queue.dequeue_all()
        if not pending:
            return

        print(f"[QUEUE] Flushing {len(pending)} pending records...")
        for record_id, payload in pending:
            try:
                self.db.collection("occupancyRecords").add(payload)
                self.queue.remove(record_id)
                print(f"[QUEUE] Flushed record #{record_id}")
            except Exception as e:
                print(f"[QUEUE] Still offline, keeping record #{record_id}: {e}")
                break  # Stop trying if still offline

    def close(self):
        self.queue.close()
        print(f"[FIREBASE] Closed. Total uploads: {self.upload_count}")
