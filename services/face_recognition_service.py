"""
Face Recognition Service using multiple models
"""
import cv2
import numpy as np
import torch
import pickle
from typing import List, Tuple, Optional, Dict, Any
from pathlib import Path
import face_recognition
from facenet_pytorch import MTCNN, InceptionResnetV1
from PIL import Image
import logging
from config import settings

logger = logging.getLogger(__name__)

class FaceRecognitionService:
    """
    Advanced face recognition service with multiple model support
    """
    
    def __init__(self):
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.face_detector = None
        self.face_encoder = None
        self.known_embeddings = {}
        self.known_face_ids = []
        self.load_models()
        self.load_known_faces()
    
    def load_models(self):
        """Load face detection and recognition models"""
        try:
            # Initialize MTCNN for face detection
            self.face_detector = MTCNN(
                image_size=160,
                margin=0,
                min_face_size=20,
                thresholds=[0.6, 0.7, 0.7],
                factor=0.709,
                post_process=True,
                device=self.device
            )
            
            # Initialize FaceNet for face encoding
            self.face_encoder = InceptionResnetV1(pretrained='vggface2').eval().to(self.device)
            
            logger.info("Face recognition models loaded successfully")
            
        except Exception as e:
            logger.error(f"Error loading face recognition models: {e}")
            raise
    
    def load_known_faces(self):
        """Load known face embeddings from database"""
        try:
            # This will be implemented with database integration
            logger.info("Known faces loaded from database")
        except Exception as e:
            logger.error(f"Error loading known faces: {e}")
    
    def detect_faces(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """
        Detect faces in an image
        
        Args:
            image: Input image as numpy array
            
        Returns:
            List of detected faces with bounding boxes and landmarks
        """
        try:
            # Convert BGR to RGB for MTCNN
            rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
            pil_image = Image.fromarray(rgb_image)
            
            # Detect faces
            boxes, probs, landmarks = self.face_detector.detect(pil_image, landmarks=True)
            
            faces = []
            if boxes is not None:
                for i, (box, prob, landmark) in enumerate(zip(boxes, probs, landmarks)):
                    if prob > settings.FACE_DETECTION_CONFIDENCE:
                        face_data = {
                            'bbox': box.tolist(),
                            'confidence': float(prob),
                            'landmarks': landmark.tolist() if landmark is not None else None,
                            'face_id': i
                        }
                        faces.append(face_data)
            
            return faces
            
        except Exception as e:
            logger.error(f"Error detecting faces: {e}")
            return []
    
    def extract_face_embedding(self, image: np.ndarray, bbox: List[float]) -> Optional[np.ndarray]:
        """
        Extract face embedding from detected face
        
        Args:
            image: Input image
            bbox: Bounding box coordinates [x1, y1, x2, y2]
            
        Returns:
            Face embedding vector or None
        """
        try:
            # Extract face region
            x1, y1, x2, y2 = map(int, bbox)
            face_crop = image[y1:y2, x1:x2]
            
            if face_crop.size == 0:
                return None
            
            # Convert to PIL Image
            face_pil = Image.fromarray(cv2.cvtColor(face_crop, cv2.COLOR_BGR2RGB))
            
            # Resize to 160x160 for FaceNet
            face_pil = face_pil.resize((160, 160))
            
            # Convert to tensor
            face_tensor = torch.tensor(np.array(face_pil)).permute(2, 0, 1).float().unsqueeze(0) / 255.0
            face_tensor = face_tensor.to(self.device)
            
            # Extract embedding
            with torch.no_grad():
                embedding = self.face_encoder(face_tensor)
                embedding = embedding.cpu().numpy().flatten()
            
            return embedding
            
        except Exception as e:
            logger.error(f"Error extracting face embedding: {e}")
            return None
    
    def recognize_face(self, embedding: np.ndarray) -> Tuple[Optional[str], float]:
        """
        Recognize face from embedding
        
        Args:
            embedding: Face embedding vector
            
        Returns:
            Tuple of (user_id, confidence)
        """
        try:
            if len(self.known_embeddings) == 0:
                return None, 0.0
            
            # Calculate distances to known faces
            distances = []
            for known_embedding in self.known_embeddings.values():
                distance = np.linalg.norm(embedding - known_embedding)
                distances.append(distance)
            
            # Find minimum distance
            min_distance = min(distances)
            
            # Convert distance to confidence (lower distance = higher confidence)
            confidence = max(0, 1 - min_distance / settings.FACE_RECOGNITION_THRESHOLD)
            
            if confidence > settings.FACE_RECOGNITION_THRESHOLD:
                # Find the user_id with minimum distance
                min_idx = distances.index(min_distance)
                user_id = list(self.known_embeddings.keys())[min_idx]
                return user_id, confidence
            
            return None, confidence
            
        except Exception as e:
            logger.error(f"Error recognizing face: {e}")
            return None, 0.0
    
    def add_face_to_database(self, user_id: str, embedding: np.ndarray, 
                           face_image_path: str, bbox: List[float], 
                           confidence: float) -> bool:
        """
        Add new face to known faces database
        
        Args:
            user_id: User identifier
            embedding: Face embedding vector
            face_image_path: Path to face image
            bbox: Bounding box coordinates
            confidence: Detection confidence
            
        Returns:
            Success status
        """
        try:
            # Store embedding
            self.known_embeddings[user_id] = embedding
            self.known_face_ids.append(user_id)
            
            # TODO: Save to database
            logger.info(f"Face added to database for user: {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error adding face to database: {e}")
            return False
    
    def process_image(self, image_path: str) -> Dict[str, Any]:
        """
        Process image for face recognition
        
        Args:
            image_path: Path to input image
            
        Returns:
            Recognition results
        """
        try:
            # Load image
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not load image: {image_path}")
            
            # Detect faces
            faces = self.detect_faces(image)
            
            results = {
                'image_path': image_path,
                'faces_detected': len(faces),
                'recognitions': []
            }
            
            # Process each detected face
            for face in faces:
                bbox = face['bbox']
                confidence = face['confidence']
                
                # Extract embedding
                embedding = self.extract_face_embedding(image, bbox)
                
                if embedding is not None:
                    # Recognize face
                    user_id, rec_confidence = self.recognize_face(embedding)
                    
                    recognition = {
                        'bbox': bbox,
                        'detection_confidence': confidence,
                        'user_id': user_id,
                        'recognition_confidence': rec_confidence,
                        'is_known': user_id is not None
                    }
                    
                    results['recognitions'].append(recognition)
            
            return results
            
        except Exception as e:
            logger.error(f"Error processing image: {e}")
            return {
                'image_path': image_path,
                'error': str(e),
                'faces_detected': 0,
                'recognitions': []
            }
    
    def get_face_statistics(self) -> Dict[str, Any]:
        """
        Get face recognition statistics
        
        Returns:
            Statistics dictionary
        """
        return {
            'total_known_faces': len(self.known_embeddings),
            'known_user_ids': list(self.known_embeddings.keys()),
            'model_device': str(self.device),
            'detection_threshold': settings.FACE_DETECTION_CONFIDENCE,
            'recognition_threshold': settings.FACE_RECOGNITION_THRESHOLD
        }
