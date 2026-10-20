import os

# Bus Configuration
BUS_ID = "bus-27"

# Camera Settings
CAMERA_INDEX = 0  # Default webcam
FPS = 1           # Process 1 frame per second to save resources
SHOW_VIDEO = True # Set to False on Raspberry Pi if running headless

# AI Settings
YOLO_MODEL = "yolov8n.pt"  # Nano model is fastest for edge devices
PERSON_CLASS_ID = 0        # In COCO dataset, 'person' is class 0
CONFIDENCE_THRESHOLD = 0.5 # Minimum confidence to count a person

# Firebase Settings
SERVICE_ACCOUNT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "serviceAccountKey.json")
