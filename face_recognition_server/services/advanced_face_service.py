"""
Advanced Face Recognition Service using OpenCV and custom models
"""
import cv2
import numpy as np
import logging
import os
import pickle
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path
import json

logger = logging.getLogger(__name__)

class AdvancedFaceService:
    """
    Advanced face recognition service with multiple detection methods
    """
    
    def __init__(self):
        self.face_cascade = None
        self.eye_cascade = None
        self.known_faces = {}
        self.face_encodings = {}
        self.load_models()
        self.load_known_faces()
    
    def load_models(self):
        """Load face detection models"""
        try:
            # Load Haar Cascade for face detection
            self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
            self.eye_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_eye.xml')
            logger.info("Face detection models loaded successfully")
        except Exception as e:
            logger.error(f"Error loading face detection models: {e}")
            raise
    
    def load_known_faces(self):
        """Load known face encodings from file"""
        try:
            faces_file = Path("known_faces.json")
            if faces_file.exists():
                with open(faces_file, 'r') as f:
                    data = json.load(f)
                    self.known_faces = data.get('faces', {})
                    self.face_encodings = data.get('encodings', {})
                logger.info(f"Loaded {len(self.known_faces)} known faces")
            else:
                logger.info("No known faces file found, starting fresh")
        except Exception as e:
            logger.error(f"Error loading known faces: {e}")
    
    def save_known_faces(self):
        """Save known face encodings to file"""
        try:
            faces_file = Path("known_faces.json")
            data = {
                'faces': self.known_faces,
                'encodings': self.face_encodings
            }
            with open(faces_file, 'w') as f:
                json.dump(data, f, indent=2)
            logger.info("Known faces saved successfully")
        except Exception as e:
            logger.error(f"Error saving known faces: {e}")
    
    def extract_face_features(self, face_image: np.ndarray) -> np.ndarray:
        """
        Extract features from face image using simple method
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Feature vector
        """
        try:
            # Resize to standard size
            face_resized = cv2.resize(face_image, (64, 64))
            
            # Convert to grayscale
            gray = cv2.cvtColor(face_resized, cv2.COLOR_BGR2GRAY)
            
            # Apply histogram equalization
            equalized = cv2.equalizeHist(gray)
            
            # Flatten to create feature vector
            features = equalized.flatten()
            
            # Normalize
            features = features.astype(np.float32) / 255.0
            
            return features
            
        except Exception as e:
            logger.error(f"Error extracting face features: {e}")
            return np.array([])
    
    def calculate_face_similarity(self, features1: np.ndarray, features2: np.ndarray) -> float:
        """
        Calculate similarity between two face feature vectors
        
        Args:
            features1: First face features
            features2: Second face features
            
        Returns:
            Similarity score (0-1)
        """
        try:
            if len(features1) == 0 or len(features2) == 0:
                return 0.0
            
            # Calculate cosine similarity
            dot_product = np.dot(features1, features2)
            norm1 = np.linalg.norm(features1)
            norm2 = np.linalg.norm(features2)
            
            if norm1 == 0 or norm2 == 0:
                return 0.0
            
            similarity = dot_product / (norm1 * norm2)
            return max(0.0, similarity)
            
        except Exception as e:
            logger.error(f"Error calculating face similarity: {e}")
            return 0.0
    
    def detect_faces(self, image_path: str) -> Dict[str, Any]:
        """
        Detect faces in an image with advanced analysis
        
        Args:
            image_path: Path to input image
            
        Returns:
            Detection results with analysis
        """
        try:
            # Load image
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not load image: {image_path}")
            
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Detect faces with optimized parameters
            faces = self.face_cascade.detectMultiScale(gray, scaleFactor=1.05, minNeighbors=3, minSize=(30, 30))
            
            # Process results
            detected_faces = []
            for i, (x, y, w, h) in enumerate(faces):
                # Extract face region
                face_region = image[y:y+h, x:x+w]
                
                # Extract features
                features = self.extract_face_features(face_region)
                
                # Detect eyes for additional validation
                face_gray = gray[y:y+h, x:x+w]
                eyes = self.eye_cascade.detectMultiScale(face_gray)
                
                # Analyze face characteristics
                face_analysis = self.analyze_face_characteristics(face_region)
                
                # Try to recognize face
                recognized_user, confidence = self.recognize_face(features)
                
                face_data = {
                    'face_id': i,
                    'bbox': [int(x), int(y), int(x + w), int(y + h)],
                    'confidence': 0.8,  # Haar cascade confidence
                    'width': int(w),
                    'height': int(h),
                    'eyes_detected': len(eyes),
                    'face_analysis': face_analysis,
                    'recognized_user': recognized_user,
                    'recognition_confidence': confidence,
                    'is_known': recognized_user is not None
                }
                detected_faces.append(face_data)
            
            return {
                'success': True,
                'image_path': image_path,
                'faces_detected': len(detected_faces),
                'faces': detected_faces,
                'image_info': {
                    'width': image.shape[1],
                    'height': image.shape[0],
                    'channels': image.shape[2] if len(image.shape) > 2 else 1
                }
            }
            
        except Exception as e:
            logger.error(f"Error detecting faces: {e}")
            return {
                'success': False,
                'error': str(e),
                'image_path': image_path,
                'faces_detected': 0,
                'faces': []
            }
    
    def analyze_face_characteristics(self, face_image: np.ndarray) -> Dict[str, Any]:
        """
        Analyze face characteristics for gender and age estimation
        
        Args:
            face_image: Face image
            
        Returns:
            Face analysis results
        """
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY)
            
            # Basic analysis
            height, width = gray.shape
            aspect_ratio = width / height
            
            # Calculate brightness and contrast
            brightness = np.mean(gray)
            contrast = np.std(gray)
            
            # Simple gender estimation based on face shape (very basic)
            gender_estimate = "unknown"
            gender_confidence = 0.5
            
            if aspect_ratio > 0.8:
                gender_estimate = "male"
                gender_confidence = 0.6
            elif aspect_ratio < 0.75:
                gender_estimate = "female"
                gender_confidence = 0.6
            
            # Simple age estimation (very basic)
            age_estimate = None
            if contrast > 50:
                age_estimate = 25 + int(contrast / 10)
            else:
                age_estimate = 20 + int(contrast / 5)
            
            return {
                'aspect_ratio': aspect_ratio,
                'brightness': brightness,
                'contrast': contrast,
                'gender_estimate': gender_estimate,
                'gender_confidence': gender_confidence,
                'age_estimate': min(80, max(18, age_estimate))
            }
            
        except Exception as e:
            logger.error(f"Error analyzing face characteristics: {e}")
            return {
                'gender_estimate': 'unknown',
                'gender_confidence': 0.0,
                'age_estimate': None
            }
    
    def recognize_face(self, features: np.ndarray) -> Tuple[Optional[str], float]:
        """
        Recognize face from features
        
        Args:
            features: Face feature vector
            
        Returns:
            Tuple of (user_id, confidence)
        """
        try:
            if len(self.face_encodings) == 0 or len(features) == 0:
                return None, 0.0
            
            best_match = None
            best_confidence = 0.0
            
            for user_id, stored_features in self.face_encodings.items():
                if len(stored_features) > 0:
                    similarity = self.calculate_face_similarity(features, np.array(stored_features))
                    if similarity > best_confidence:
                        best_confidence = similarity
                        best_match = user_id
            
            # Threshold for recognition
            if best_confidence > 0.7:
                return best_match, best_confidence
            
            return None, best_confidence
            
        except Exception as e:
            logger.error(f"Error recognizing face: {e}")
            return None, 0.0
    
    def add_face(self, image_path: str, user_id: str, user_name: str) -> Dict[str, Any]:
        """
        Add a new face to the known faces database
        
        Args:
            image_path: Path to face image
            user_id: User identifier
            user_name: User name
            
        Returns:
            Addition result
        """
        try:
            # Detect faces in image
            result = self.detect_faces(image_path)
            
            if not result['success'] or result['faces_detected'] == 0:
                return {
                    'success': False,
                    'error': 'No faces detected in image',
                    'user_id': user_id
                }
            
            # Get the best face (largest)
            best_face = max(result['faces'], key=lambda x: x['width'] * x['height'])
            
            # Extract features from the best face
            image = cv2.imread(image_path)
            x, y, w, h = best_face['bbox']
            face_region = image[y:y+h, x:x+w]
            features = self.extract_face_features(face_region)
            
            if len(features) == 0:
                return {
                    'success': False,
                    'error': 'Could not extract face features',
                    'user_id': user_id
                }
            
            # Store face data
            self.known_faces[user_id] = {
                'name': user_name,
                'image_path': image_path,
                'face_analysis': best_face['face_analysis']
            }
            
            self.face_encodings[user_id] = features.tolist()
            
            # Save to file
            self.save_known_faces()
            
            return {
                'success': True,
                'user_id': user_id,
                'user_name': user_name,
                'face_analysis': best_face['face_analysis'],
                'message': 'Face added successfully'
            }
            
        except Exception as e:
            logger.error(f"Error adding face: {e}")
            return {
                'success': False,
                'error': str(e),
                'user_id': user_id
            }
    
    def get_known_faces(self) -> Dict[str, Any]:
        """
        Get list of known faces
        
        Returns:
            Known faces information
        """
        return {
            'total_faces': len(self.known_faces),
            'faces': self.known_faces
        }
    
    def delete_face(self, user_id: str) -> bool:
        """
        Delete a face from known faces
        
        Args:
            user_id: User identifier
            
        Returns:
            Success status
        """
        try:
            if user_id in self.known_faces:
                del self.known_faces[user_id]
            if user_id in self.face_encodings:
                del self.face_encodings[user_id]
            
            self.save_known_faces()
            return True
            
        except Exception as e:
            logger.error(f"Error deleting face: {e}")
            return False
    
    def get_service_stats(self) -> Dict[str, Any]:
        """
        Get service statistics
        
        Returns:
            Statistics dictionary
        """
        return {
            'model_loaded': self.face_cascade is not None,
            'model_type': 'Haar Cascade + Custom Features',
            'version': '2.0.0',
            'status': 'ready',
            'known_faces_count': len(self.known_faces),
            'supported_features': [
                'face_detection',
                'face_recognition',
                'gender_estimation',
                'age_estimation',
                'eye_detection'
            ]
        }
