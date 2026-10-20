"""Quick seed for the active trip on route-1."""
import uuid
import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceAccountKey.json")
app = firebase_admin.initialize_app(cred)
db = firestore.client()

# Find the active trip for route-1
trips = db.collection("trips").where("routeId", "==", "route-1").where("status", "==", "Active").stream()
trip = None
for t in trips:
    trip = t
    break

if not trip:
    print("No active trip found for route-1!")
    firebase_admin.delete_app(app)
    exit()

trip_id = trip.id
print(f"Trip ID: {trip_id}")

# Get the route's stop IDs
route_doc = db.collection("routes").document("route-1").get()
stop_ids = route_doc.to_dict().get("stopIds", [])
print(f"Stops: {stop_ids}")

# Get stop names
for sid in stop_ids:
    s = db.collection("stops").document(sid).get()
    name = s.to_dict().get("name", "?") if s.exists else "?"
    print(f"  {sid} -> {name}")

# Clear ALL existing check-ins for this trip first
existing = db.collection("checkIns").where("tripID", "==", trip_id).stream()
batch = db.batch()
for doc in existing:
    batch.delete(doc.reference)
batch.commit()
print("\nCleared all existing check-ins.")

# Seed: Stop 1 (University of Jordan) = 11, Stop 2 = 5, Stop 3 = 0
counts = [11, 5, 0]
for i, sid in enumerate(stop_ids):
    c = counts[i] if i < len(counts) else 0
    if c > 0:
        batch = db.batch()
        for j in range(c):
            ref = db.collection("checkIns").document(f"demo-{uuid.uuid4().hex[:8]}")
            batch.set(ref, {
                "tripID": trip_id,
                "stopID": sid,
                "passengerID": f"demo-passenger-{i}-{j}",
                "passengerCount": 1,
                "timestamp": firestore.SERVER_TIMESTAMP,
            })
        batch.commit()
    s = db.collection("stops").document(sid).get()
    name = s.to_dict().get("name", sid) if s.exists else sid
    print(f"  {name}: {c} waiting")

print("\nDone! Check the driver dashboard.")
firebase_admin.delete_app(app)
