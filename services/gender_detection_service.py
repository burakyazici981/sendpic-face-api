"""
Gender Detection Service using deep learning models
"""
import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from typing import List, Tuple, Optional, Dict, Any
from PIL import Image
import logging
from config import settings

logger = logging.getLogger(__name__)

class GenderClassifier(nn.Module):
    """
    Simple CNN for gender classification
    """
    def __init__(self, num_classes=2):
        super(GenderClassifier, self).__init__()
        self.conv1 = nn.Conv2d(3, 32, kernel_size=3, padding=1)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        self.conv3 = nn.Conv2d(64, 128, kernel_size=3, padding=1)
        self.pool = nn.MaxPool2d(2, 2)
        self.dropout = nn.Dropout(0.5)
        self.fc1 = nn.Linear(128 * 8 * 8, 512)
        self.fc2 = nn.Linear(512, num_classes)
        
    def forward(self, x):
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = self.pool(F.relu(self.conv3(x)))
        x = x.view(-1, 128 * 8 * 8)
        x = self.dropout(F.relu(self.fc1(x)))
        x = self.fc2(x)
        return x

class GenderDetectionService:
    """
    Gender detection service using multiple approaches
    """
    
    def __init__(self):
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.gender_model = None
        self.age_model = None
        self.load_models()
    
    def load_models(self):
        """Load gender and age detection models"""
        try:
            # Initialize gender classifier
            self.gender_model = GenderClassifier(num_classes=2)
            self.gender_model.to(self.device)
            self.gender_model.eval()
            
            # Load pretrained weights if available
            model_path = Path(settings.MODELS_DIR) / f"{settings.GENDER_MODEL}.pth"
            if model_path.exists():
                self.gender_model.load_state_dict(torch.load(model_path, map_location=self.device))
                logger.info("Gender model loaded successfully")
            else:
                logger.warning("Gender model weights not found, using random initialization")
            
            logger.info("Gender detection models initialized")
            
        except Exception as e:
            logger.error(f"Error loading gender detection models: {e}")
            raise
    
    def preprocess_face(self, face_image: np.ndarray) -> torch.Tensor:
        """
        Preprocess face image for gender classification
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Preprocessed tensor
        """
        try:
            # Resize to 64x64 for gender classification
            face_resized = cv2.resize(face_image, (64, 64))
            
            # Normalize to [0, 1]
            face_normalized = face_resized.astype(np.float32) / 255.0
            
            # Convert to tensor and add batch dimension
            face_tensor = torch.tensor(face_normalized).permute(2, 0, 1).unsqueeze(0)
            face_tensor = face_tensor.to(self.device)
            
            return face_tensor
            
        except Exception as e:
            logger.error(f"Error preprocessing face: {e}")
            return None
    
    def predict_gender(self, face_image: np.ndarray) -> Tuple[str, float]:
        """
        Predict gender from face image
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Tuple of (gender, confidence)
        """
        try:
            # Preprocess face
            face_tensor = self.preprocess_face(face_image)
            if face_tensor is None:
                return "unknown", 0.0
            
            # Predict gender
            with torch.no_grad():
                outputs = self.gender_model(face_tensor)
                probabilities = F.softmax(outputs, dim=1)
                confidence, predicted = torch.max(probabilities, 1)
                
                gender = "female" if predicted.item() == 0 else "male"
                confidence_score = confidence.item()
            
            return gender, confidence_score
            
        except Exception as e:
            logger.error(f"Error predicting gender: {e}")
            return "unknown", 0.0
    
    def predict_gender_advanced(self, face_image: np.ndarray) -> Dict[str, Any]:
        """
        Advanced gender prediction with additional features
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Detailed gender prediction results
        """
        try:
            # Basic gender prediction
            gender, confidence = self.predict_gender(face_image)
            
            # Additional analysis
            results = {
                'gender': gender,
                'confidence': confidence,
                'is_confident': confidence > settings.GENDER_CONFIDENCE_THRESHOLD,
                'age_estimate': self.estimate_age(face_image),
                'facial_features': self.analyze_facial_features(face_image)
            }
            
            return results
            
        except Exception as e:
            logger.error(f"Error in advanced gender prediction: {e}")
            return {
                'gender': 'unknown',
                'confidence': 0.0,
                'is_confident': False,
                'age_estimate': None,
                'facial_features': {}
            }
    
    def estimate_age(self, face_image: np.ndarray) -> Optional[int]:
        """
        Estimate age from face image (simplified approach)
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Estimated age or None
        """
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY)
            
            # Simple age estimation based on facial features
            # This is a placeholder - in production, use a proper age estimation model
            
            # Analyze face shape and features
            height, width = gray.shape
            aspect_ratio = width / height
            
            # Very basic age estimation (not accurate, just for demonstration)
            if aspect_ratio > 0.8:
                age_estimate = np.random.randint(25, 45)  # Adult
            else:
                age_estimate = np.random.randint(18, 30)  # Young adult
            
            return age_estimate
            
        except Exception as e:
            logger.error(f"Error estimating age: {e}")
            return None
    
    def analyze_facial_features(self, face_image: np.ndarray) -> Dict[str, Any]:
        """
        Analyze facial features for gender classification
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Facial features analysis
        """
        try:
            # Convert to grayscale
            gray = cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY)
            
            # Analyze facial features
            features = {
                'face_width': face_image.shape[1],
                'face_height': face_image.shape[0],
                'aspect_ratio': face_image.shape[1] / face_image.shape[0],
                'brightness': np.mean(gray),
                'contrast': np.std(gray)
            }
            
            return features
            
        except Exception as e:
            logger.error(f"Error analyzing facial features: {e}")
            return {}
    
    def batch_predict_gender(self, face_images: List[np.ndarray]) -> List[Dict[str, Any]]:
        """
        Predict gender for multiple faces
        
        Args:
            face_images: List of face images
            
        Returns:
            List of gender prediction results
        """
        results = []
        for face_image in face_images:
            result = self.predict_gender_advanced(face_image)
            results.append(result)
        
        return results
    
    def get_gender_statistics(self) -> Dict[str, Any]:
        """
        Get gender detection statistics
        
        Returns:
            Statistics dictionary
        """
        return {
            'model_device': str(self.device),
            'confidence_threshold': settings.GENDER_CONFIDENCE_THRESHOLD,
            'model_loaded': self.gender_model is not None,
            'supports_batch_processing': True
        }
