"""
Simple Face Recognition Service for testing
"""
import cv2
import numpy as np
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

class SimpleFaceService:
    """
    Simple face recognition service using OpenCV
    """
    
    def __init__(self):
        self.face_cascade = None
        self.load_models()
    
    def load_models(self):
        """Load face detection models"""
        try:
            # Load Haar Cascade for face detection
            self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
            logger.info("Face detection model loaded successfully")
        except Exception as e:
            logger.error(f"Error loading face detection model: {e}")
            raise
    
    def detect_faces(self, image_path: str) -> Dict[str, Any]:
        """
        Detect faces in an image
        
        Args:
            image_path: Path to input image
            
        Returns:
            Detection results
        """
        try:
            # Load image
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not load image: {image_path}")
            
            # Convert to grayscale
            gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
            
            # Detect faces
            faces = self.face_cascade.detectMultiScale(gray, 1.1, 4)
            
            # Process results
            detected_faces = []
            for (x, y, w, h) in faces:
                face_data = {
                    'bbox': [int(x), int(y), int(x + w), int(y + h)],
                    'confidence': 0.8,  # Haar cascade doesn't provide confidence
                    'width': int(w),
                    'height': int(h)
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
    
    def get_service_stats(self) -> Dict[str, Any]:
        """
        Get service statistics
        
        Returns:
            Statistics dictionary
        """
        return {
            'model_loaded': self.face_cascade is not None,
            'model_type': 'Haar Cascade',
            'version': '1.0.0',
            'status': 'ready'
        }
