# SDBS Edge Module — AI Occupancy Detection

This Python module runs on a **Raspberry Pi 4 + Coral USB TPU** inside each bus (or on your laptop webcam for testing). It detects passengers using YOLOv8 and uploads the count to Firebase Firestore in real time.

## Setup (One-Time)

### 1. Install Python Dependencies
```bash
cd edge-module
pip install -r requirements.txt
```

### 2. Place Firebase Service Account Key
Download from Firebase Console → Project Settings → Service Accounts → Generate New Private Key.  
Save as `serviceAccountKey.json` in this folder.

### 3. First Run (Downloads YOLOv8 model automatically)
```bash
python main.py
```
The first run will download the YOLOv8n model (~6MB). After that, it's cached.

## Usage

```bash
# Default: use webcam, bus-27
python main.py

# Specify a different bus
python main.py --bus-id bus-28

# Use a video file instead of live camera
python main.py --source path/to/video.mp4

# Run headless (no video window, for Raspberry Pi)
python main.py --no-video

# Adjust detection confidence
python main.py --confidence 0.6

# All options together
python main.py --bus-id bus-28 --fps 2 --confidence 0.4 --no-video
```

## How It Works

```
Camera (1 fps) → YOLOv8n → Count People → Upload to Firestore
                                              ↓
                                    occupancyRecords collection
                                    buses/{busId}.currentOccupancy
```

1. **Frame Capture (AI-01):** OpenCV captures frames at 1 fps.
2. **Detection (AI-02):** YOLOv8n detects "person" class objects.
3. **Confidence Gating (AI-03):** Low-confidence frames use the last valid count.
4. **Upload (AI-04):** Sends `{busId, count, confidence, timestamp}` to Firestore.
5. **Offline Queue (AI-05):** Failed uploads are saved to SQLite and retried automatically.

## Files

| File | Purpose |
|------|---------|
| `main.py` | Entry point and CLI argument parsing |
| `detector.py` | YOLOv8 camera capture and person detection |
| `uploader.py` | Firebase Firestore upload + bus status update |
| `offline_queue.py` | SQLite queue for network failure resilience |
| `config.py` | All configurable settings |

## Testing on Laptop

Point your webcam at:
- Yourself (should count 1 person)
- A photo of a crowd on your phone screen
- A YouTube video of people walking

The count will appear in your Firebase `occupancyRecords` collection and update the Driver Dashboard in real time.
