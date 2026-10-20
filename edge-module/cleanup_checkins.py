"""
Cleanup: Delete all checkIn records that belong to completed/cancelled trips.
This fixes the inflated 'Check-Ins by Stop' report numbers.
"""
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceAccountKey.json")
app = firebase_admin.initialize_app(cred)
db = firestore.client()

# 1. Get all ACTIVE trip IDs
active_trips = db.collection("trips").where("status", "==", "Active").stream()
active_ids = {t.id for t in active_trips}
print(f"Active trips: {active_ids}")

# 2. Get ALL check-ins
all_checkins = db.collection("checkIns").stream()

# 3. Delete any check-in that does NOT belong to an active trip
batch = db.batch()
count = 0
for doc in all_checkins:
    trip_id = doc.to_dict().get("tripID", "")
    if trip_id not in active_ids:
        batch.delete(doc.reference)
        count += 1

batch.commit()
print(f"\nDeleted {count} stale check-in(s) from old/completed trips.")
print("Reports should now show accurate numbers.")

firebase_admin.delete_app(app)
