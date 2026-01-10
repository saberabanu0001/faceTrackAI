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
            
            # Handle multiple faces: find the best match
            # Strategy: Compare each face in Image 1 with each face in Image 2
            # Return the best match (highest similarity score)
            
            best_similarity = -1.0
            
            # Compare all faces in Image 1 against all faces in Image 2
            # Find the best match across all combinations
            for encoding1 in encodings1:
                # Calculate distances from this face in Image 1 to all faces in Image 2
                distances = face_recognition.face_distance(encodings2, encoding1)
                
                # For each face in Image 2, calculate similarity
                for distance in distances:
                    similarity = 1.0 - distance
                    # Keep track of the best match found
                    if similarity > best_similarity:
                        best_similarity = similarity
            
            # If multiple faces detected, log information
            if len(encodings1) > 1:
                print(f"ℹ️  Multiple faces detected in Image 1 ({len(encodings1)} faces). Comparing against all faces and using best match.")
            if len(encodings2) > 1:
                print(f"ℹ️  Multiple faces detected in Image 2 ({len(encodings2)} faces). Comparing against all faces and using best match.")
            
            # Determine if faces match based on SIMILARITY threshold
            # The best match must meet the threshold to be considered "same person"
            is_same = best_similarity >= threshold
            
            return best_similarity, is_same
            
        except Exception as exc:
            raise ValueError(f"Error during face comparison: {exc}") from exc
