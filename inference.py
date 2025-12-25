import os
import face_recognition
import numpy as np


class FaceAnalysis:
    def __init__(self):
        """
        Initialize FaceAnalysis with face_recognition library.
        Uses dlib's face recognition model which is accurate and fast.
        """
        print("✅ Using face_recognition library (dlib-based)")
        print("   Model will be loaded on first use.")

    def compare(self, img1_path, img2_path, threshold=0.6):
        """
        Compare two face images and determine if they are the same person.
        
        Args:
            img1_path: Path to first image
            img2_path: Path to second image
            threshold: Similarity threshold (higher = stricter).
                       Typical values:
                       - 0.7-0.8: Very strict (fewer false positives)
                       - 0.6-0.7: Normal (default, good balance)
                       - 0.5-0.6: Lenient (more matches, may have false positives)
                       Note: This is a SIMILARITY threshold (higher = more similar)
        
        Returns:
            tuple: (similarity_score, is_same_person)
                   similarity_score: 1.0 = identical, 0.0 = completely different
                   is_same_person: boolean indicating if faces match
        """
        if not os.path.exists(img1_path):
            raise FileNotFoundError(f"Image not found: {img1_path}")
        if not os.path.exists(img2_path):
            raise FileNotFoundError(f"Image not found: {img2_path}")

        try:
            # Load images
            image1 = face_recognition.load_image_file(img1_path)
            image2 = face_recognition.load_image_file(img2_path)
            
            # Get face encodings (128-dimensional vectors)
            encodings1 = face_recognition.face_encodings(image1)
            encodings2 = face_recognition.face_encodings(image2)
            
            # Check if faces were detected
            if len(encodings1) == 0:
                raise ValueError(f"No face detected in {img1_path}. Make sure the image contains a clear, front-facing face.")
            if len(encodings2) == 0:
                raise ValueError(f"No face detected in {img2_path}. Make sure the image contains a clear, front-facing face.")
            
            # If multiple faces, use the first one
            encoding1 = encodings1[0]
            encoding2 = encodings2[0]
            
            # Calculate face distance (lower = more similar)
            # face_distance returns values typically between 0.0 and 1.0
            # 0.0 = identical faces, 1.0 = completely different
            distance = face_recognition.face_distance([encoding1], encoding2)[0]
            
            # Convert distance to similarity score (0-1, higher = more similar)
            # face_distance is already normalized, so similarity = 1 - distance
            similarity = 1.0 - distance
            
            # Determine if faces match based on SIMILARITY threshold
            # Higher similarity = more likely same person
            # So we check if similarity >= threshold
            is_same = similarity >= threshold
            
            return similarity, is_same
            
        except Exception as exc:
            raise ValueError(f"Error during face comparison: {exc}") from exc
