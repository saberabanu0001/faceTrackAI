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
            tuple: (similarity_score, is_same_person, match_info)
                   similarity_score: 1.0 = identical, 0.0 = completely different
                   is_same_person: boolean indicating if faces match
                   match_info: dict with face locations and match details
                     - face1_location: bounding box for matched face in image1 (top, right, bottom, left)
                     - face2_location: bounding box for matched face in image2 (top, right, bottom, left)
                     - multiple_faces_image1: boolean indicating if image1 had multiple faces
                     - multiple_faces_image2: boolean indicating if image2 had multiple faces
        """
        if not os.path.exists(img1_path):
            raise FileNotFoundError(f"Image not found: {img1_path}")
        if not os.path.exists(img2_path):
            raise FileNotFoundError(f"Image not found: {img2_path}")

        try:
            # Load images
            image1 = face_recognition.load_image_file(img1_path)
            image2 = face_recognition.load_image_file(img2_path)
            
            # Get face encodings and locations
            encodings1 = face_recognition.face_encodings(image1)
            encodings2 = face_recognition.face_encodings(image2)
            locations1 = face_recognition.face_locations(image1)
            locations2 = face_recognition.face_locations(image2)
            
            # Check if faces were detected
            if len(encodings1) == 0:
                raise ValueError(f"No face detected in {img1_path}. Make sure the image contains a clear, front-facing face.")
            if len(encodings2) == 0:
                raise ValueError(f"No face detected in {img2_path}. Make sure the image contains a clear, front-facing face.")
            
            # Handle multiple faces: find the best match
            # Strategy: Compare each face in Image 1 with each face in Image 2
            # Return the best match (highest similarity score) with bounding box locations
            
            best_similarity = -1.0
            best_face1_idx = 0  # Index of best matching face in Image 1
            best_face2_idx = 0  # Index of best matching face in Image 2
            
            # Compare all faces in Image 1 against all faces in Image 2
            # Find the best match across all combinations
            for i, encoding1 in enumerate(encodings1):
                # Calculate distances from this face in Image 1 to all faces in Image 2
                distances = face_recognition.face_distance(encodings2, encoding1)
                
                # Find the best match for this face in Image 1
                for j, distance in enumerate(distances):
                    similarity = 1.0 - distance
                    # Keep track of the best match found
                    if similarity > best_similarity:
                        best_similarity = similarity
                        best_face1_idx = i
                        best_face2_idx = j
            
            
            # Get bounding boxes for the matched faces
            # face_locations returns (top, right, bottom, left) tuples
            matched_face1_location = locations1[best_face1_idx]
            matched_face2_location = locations2[best_face2_idx]
            
            # If multiple faces detected, log information
            multiple_faces_img1 = len(encodings1) > 1
            multiple_faces_img2 = len(encodings2) > 1
            
            if multiple_faces_img1:
                print(f"ℹ️  Multiple faces detected in Image 1 ({len(encodings1)} faces). Best match found at face #{best_face1_idx + 1}.")
            if multiple_faces_img2:
                print(f"ℹ️  Multiple faces detected in Image 2 ({len(encodings2)} faces). Best match found at face #{best_face2_idx + 1}.")
            
            # Determine if faces match based on SIMILARITY threshold
            # The best match must meet the threshold to be considered "same person"
            is_same = best_similarity >= threshold
            
            # Prepare match info with bounding boxes
            # Convert to dict format: {top, right, bottom, left} for easier JSON serialization
            match_info = {
                "face1_location": {
                    "top": int(matched_face1_location[0]),
                    "right": int(matched_face1_location[1]),
                    "bottom": int(matched_face1_location[2]),
                    "left": int(matched_face1_location[3])
                },
                "face2_location": {
                    "top": int(matched_face2_location[0]),
                    "right": int(matched_face2_location[1]),
                    "bottom": int(matched_face2_location[2]),
                    "left": int(matched_face2_location[3])
                },
                "multiple_faces_image1": multiple_faces_img1,
                "multiple_faces_image2": multiple_faces_img2,
                "total_faces_image1": len(encodings1),
                "total_faces_image2": len(encodings2),
            }
            
            return best_similarity, is_same, match_info
            
        except Exception as exc:
            raise ValueError(f"Error during face comparison: {exc}") from exc
