"""
detector.py — YOLOv8 Person Detection Module (AI-01, AI-02, AI-03)

Captures frames from camera, runs YOLOv8n inference,
counts people, and applies confidence gating.
"""

import cv2
import time
from ultralytics import YOLO
from config import (
    CAMERA_INDEX, YOLO_MODEL, PERSON_CLASS_ID,
    CONFIDENCE_THRESHOLD, FPS, SHOW_VIDEO
)


class PersonDetector:
    def __init__(self, source=None):
        """
        Initialize the detector.
        Args:
            source: Camera index (int), video file path (str), or image path.
                    Defaults to CAMERA_INDEX from config.
        """
        self.source = source if source is not None else CAMERA_INDEX
        self.model = YOLO(YOLO_MODEL)
        self.last_valid_count = 0
        self.cap = None

    def start_camera(self):
        """Open the video/camera source."""
        self.cap = cv2.VideoCapture(self.source)
        if not self.cap.isOpened():
            raise RuntimeError(f"Cannot open camera/video source: {self.source}")
        print(f"[CAMERA] Opened source: {self.source}")

    def stop_camera(self):
        """Release camera resources."""
        if self.cap and self.cap.isOpened():
            self.cap.release()
        if SHOW_VIDEO:
            cv2.destroyAllWindows()
        print("[CAMERA] Released.")

    def detect_frame(self, frame):
        
        results = self.model(frame, verbose=False)[0]

        person_detections = []
        for box in results.boxes:
            cls_id = int(box.cls[0])
            conf = float(box.conf[0])
            if cls_id == PERSON_CLASS_ID:
                person_detections.append(conf)

        count = len(person_detections)
        avg_conf = sum(person_detections) / count if count > 0 else 0.0

        #Confidence Gate
        is_valid = avg_conf >= CONFIDENCE_THRESHOLD or count == 0
        if is_valid and count > 0:
            self.last_valid_count = count
        elif not is_valid:
            # Use last valid count when confidence is low
            count = self.last_valid_count
            print(f"[WARN] Low confidence ({avg_conf:.2f}), using last valid count: {count}")

        
        annotated = results.plot()

        return count, avg_conf, is_valid, annotated

    def run_detection_loop(self, callback, max_frames=None):
        """
        Main detection loop. Captures frames at configured FPS,
        runs detection, and calls `callback(count, confidence, is_valid)`.

        Args:
            callback: Function called with (count, confidence, is_valid) after each detection.
            max_frames: If set, stop after this many frames (for testing).
        """
        self.start_camera()
        interval = 1.0 / FPS

        print(f"[DETECTOR] Running at {FPS} fps (interval: {interval}s)")
        print(f"[DETECTOR] Confidence threshold: {CONFIDENCE_THRESHOLD}")
        if max_frames:
            print(f"[DETECTOR] Will stop after {max_frames} frames")
        else:
            print(f"[DETECTOR] Press 'q' to quit (if video window is shown)")
        print("=" * 50)

        frame_count = 0
        try:
            while True:
                start_time = time.time()

                ret, frame = self.cap.read()
                if not ret:
                    print("[CAMERA] No frame received. End of video or camera error.")
                    break

                count, confidence, is_valid, annotated = self.detect_frame(frame)
                frame_count += 1

                # Call the upload/processing callback
                callback(count, confidence, is_valid)

                # Display video if enabled
                if SHOW_VIDEO:
                    # Add overlay text
                    overlay_text = f"People: {count} | Conf: {confidence:.2f} | {'VALID' if is_valid else 'LOW CONF'}"
                    cv2.putText(annotated, overlay_text, (10, 30),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
                    cv2.imshow("SDBS Occupancy Detection", annotated)

                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        print("[USER] Quit requested.")
                        break

                # Check frame limit
                if max_frames and frame_count >= max_frames:
                    print(f"[DETECTOR] Reached {max_frames} frames. Stopping.")
                    break

                # Maintain target FPS
                elapsed = time.time() - start_time
                sleep_time = max(0, interval - elapsed)
                if sleep_time > 0:
                    time.sleep(sleep_time)

        except KeyboardInterrupt:
            print("\n[USER] Ctrl+C detected. Shutting down...")
        finally:
            self.stop_camera()
            print(f"[DETECTOR] Processed {frame_count} total frames.")

