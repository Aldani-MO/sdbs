"""
SDBS Edge Module — AI Occupancy Detection
==========================================

Main entry point. Orchestrates:
  1. Camera frame capture (AI-01)
  2. YOLOv8 person detection (AI-02)
  3. Confidence gating (AI-03)
  4. Firebase upload (AI-04)
  5. Offline queue retry (AI-05)

Usage:
  python main.py                        # Use default webcam, bus-27
  python main.py --bus-id bus-28        # Override bus ID
  python main.py --source video.mp4    # Use video file instead of camera
  python main.py --source 0            # Use camera index 0
  python main.py --no-video            # Run headless (no display window)
"""

import argparse
import sys
import os

# Ensure local modules are importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import config
from detector import PersonDetector
from uploader import FirebaseUploader


def main():
    parser = argparse.ArgumentParser(description="SDBS AI Occupancy Module")
    parser.add_argument("--bus-id", type=str, default=None,
                        help=f"Bus identifier (default: {config.BUS_ID})")
    parser.add_argument("--source", type=str, default=None,
                        help="Camera index or video file path (default: webcam 0)")
    parser.add_argument("--fps", type=int, default=None,
                        help=f"Frames per second to process (default: {config.FPS})")
    parser.add_argument("--no-video", action="store_true",
                        help="Run headless without displaying video window")
    parser.add_argument("--confidence", type=float, default=None,
                        help=f"Minimum confidence threshold (default: {config.CONFIDENCE_THRESHOLD})")
    parser.add_argument("--max-frames", type=int, default=None,
                        help="Stop after N frames (for testing). Default: run forever.")
    args = parser.parse_args()

    # Override config with CLI arguments
    if args.bus_id:
        config.BUS_ID = args.bus_id
    if args.fps:
        config.FPS = args.fps
    if args.no_video:
        config.SHOW_VIDEO = False
    if args.confidence:
        config.CONFIDENCE_THRESHOLD = args.confidence

    # Parse source (could be int for camera index or string for file)
    source = None
    if args.source:
        try:
            source = int(args.source)
        except ValueError:
            source = args.source

    # Print startup banner
    print("=" * 55)
    print("  SDBS — Smart Dynamic Bus System")
    print("  AI Occupancy Detection Module")
    print("=" * 55)
    print(f"  Bus ID       : {config.BUS_ID}")
    print(f"  Source        : {source if source is not None else f'Webcam ({config.CAMERA_INDEX})'}")
    print(f"  FPS           : {config.FPS}")
    print(f"  Confidence    : {config.CONFIDENCE_THRESHOLD}")
    print(f"  Show Video    : {config.SHOW_VIDEO}")
    print("=" * 55)
    print()

    # Initialize components
    uploader = FirebaseUploader()
    detector = PersonDetector(source=source)

    # Define what happens after each detection
    def on_detection(count, confidence, is_valid):
        uploader.upload_record(count, confidence, is_valid)

    # Start the detection loop
    try:
        detector.run_detection_loop(callback=on_detection, max_frames=args.max_frames)
    finally:
        uploader.close()
        print("\n[DONE] Module shut down cleanly.")


if __name__ == "__main__":
    main()
