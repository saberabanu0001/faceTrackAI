import argparse
from pathlib import Path

from inference import FaceAnalysis


def parse_args():
    parser = argparse.ArgumentParser(description="Compare two face images.")
    parser.add_argument(
        "--img1",
        default="face1.jpeg",
        help="Path to first image (default: face1.jpeg)",
    )
    parser.add_argument(
        "--img2",
        default="face2.jpeg",
        help="Path to second image (default: face2.jpeg)",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.75,
        help="Cosine similarity threshold for same-person decision.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    img1_path = Path(args.img1)
    img2_path = Path(args.img2)

    print("⏳ Initializing models...")
    app = FaceAnalysis()

    print(f"🔍 Comparing {img1_path} vs {img2_path}...")
    try:
        similarity, is_same = app.compare(str(img1_path), str(img2_path), args.threshold)
    except Exception as exc:
        print(f"Error: {exc}")
        print("Tip: Make sure the image paths are correct and readable.")
        return

    print("-" * 30)
    print(f"🔹 Similarity Score: {similarity:.4f}")
    print("-" * 30)
    if is_same:
        print("✅ RESULT: SAME PERSON")
    else:
        print("❌ RESULT: DIFFERENT PERSON")


if __name__ == "__main__":
    main()
