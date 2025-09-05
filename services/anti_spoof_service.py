"""
Anti-Spoofing Service to detect fake faces and prevent spoofing attacks
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

class AntiSpoofCNN(nn.Module):
    """
    CNN model for anti-spoofing detection
    """
    def __init__(self, num_classes=2):
        super(AntiSpoofCNN, self).__init__()
        self.conv1 = nn.Conv2d(3, 32, kernel_size=3, padding=1)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, padding=1)
        self.conv3 = nn.Conv2d(64, 128, kernel_size=3, padding=1)
        self.conv4 = nn.Conv2d(128, 256, kernel_size=3, padding=1)
        self.pool = nn.MaxPool2d(2, 2)
        self.dropout = nn.Dropout(0.5)
        self.fc1 = nn.Linear(256 * 4 * 4, 512)
        self.fc2 = nn.Linear(512, 256)
        self.fc3 = nn.Linear(256, num_classes)
        
    def forward(self, x):
        x = self.pool(F.relu(self.conv1(x)))
        x = self.pool(F.relu(self.conv2(x)))
        x = self.pool(F.relu(self.conv3(x)))
        x = self.pool(F.relu(self.conv4(x)))
        x = x.view(-1, 256 * 4 * 4)
        x = self.dropout(F.relu(self.fc1(x)))
        x = self.dropout(F.relu(self.fc2(x)))
        x = self.fc3(x)
        return x

class AntiSpoofService:
    """
    Anti-spoofing service to detect fake faces and prevent attacks
    """
    
    def __init__(self):
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        self.spoof_model = None
        self.load_models()
    
    def load_models(self):
        """Load anti-spoofing models"""
        try:
            # Initialize anti-spoof model
            self.spoof_model = AntiSpoofCNN(num_classes=2)
            self.spoof_model.to(self.device)
            self.spoof_model.eval()
            
            # Load pretrained weights if available
            model_path = Path(settings.MODELS_DIR) / f"{settings.ANTI_SPOOF_MODEL}.pth"
            if model_path.exists():
                self.spoof_model.load_state_dict(torch.load(model_path, map_location=self.device))
                logger.info("Anti-spoof model loaded successfully")
            else:
                logger.warning("Anti-spoof model weights not found, using random initialization")
            
            logger.info("Anti-spoofing models initialized")
            
        except Exception as e:
            logger.error(f"Error loading anti-spoofing models: {e}")
            raise
    
    def preprocess_for_spoof_detection(self, face_image: np.ndarray) -> torch.Tensor:
        """
        Preprocess face image for spoof detection
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Preprocessed tensor
        """
        try:
            # Resize to 128x128 for spoof detection
            face_resized = cv2.resize(face_image, (128, 128))
            
            # Normalize to [0, 1]
            face_normalized = face_resized.astype(np.float32) / 255.0
            
            # Convert to tensor and add batch dimension
            face_tensor = torch.tensor(face_normalized).permute(2, 0, 1).unsqueeze(0)
            face_tensor = face_tensor.to(self.device)
            
            return face_tensor
            
        except Exception as e:
            logger.error(f"Error preprocessing face for spoof detection: {e}")
            return None
    
    def detect_spoof(self, face_image: np.ndarray) -> Tuple[bool, float, str]:
        """
        Detect if face is spoofed (fake)
        
        Args:
            face_image: Face image as numpy array
            
        Returns:
            Tuple of (is_spoof, confidence, spoof_type)
        """
        try:
            # Preprocess face
            face_tensor = self.preprocess_for_spoof_detection(face_image)
            if face_tensor is None:
                return True, 1.0, "preprocessing_error"
            
            # Predict spoof
            with torch.no_grad():
                outputs = self.spoof_model(face_tensor)
                probabilities = F.softmax(outputs, dim=1)
                confidence, predicted = torch.max(probabilities, dim=1)
                
                is_spoof = predicted.item() == 1  # 1 = spoof, 0 = real
                spoof_confidence = confidence.item()
                
                # Determine spoof type based on additional analysis
                spoof_type = self.determine_spoof_type(face_image, is_spoof, spoof_confidence)
            
            return is_spoof, spoof_confidence, spoof_type
            
        except Exception as e:
            logger.error(f"Error detecting spoof: {e}")
            return True, 1.0, "detection_error"
    
    def determine_spoof_type(self, face_image: np.ndarray, is_spoof: bool, confidence: float) -> str:
        """
        Determine the type of spoofing attack
        
        Args:
            face_image: Face image
            is_spoof: Whether face is detected as spoof
            confidence: Detection confidence
            
        Returns:
            Spoof type string
        """
        try:
            if not is_spoof:
                return "real"
            
            # Analyze image characteristics to determine spoof type
            gray = cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY)
            
            # Check for photo attack (printed photo)
            if self.detect_photo_attack(gray):
                return "photo"
            
            # Check for video attack (screen replay)
            if self.detect_video_attack(face_image):
                return "video"
            
            # Check for mask attack
            if self.detect_mask_attack(face_image):
                return "mask"
            
            # Check for 3D mask
            if self.detect_3d_mask(face_image):
                return "3d_mask"
            
            return "unknown_spoof"
            
        except Exception as e:
            logger.error(f"Error determining spoof type: {e}")
            return "unknown"
    
    def detect_photo_attack(self, gray_image: np.ndarray) -> bool:
        """
        Detect photo attack using texture analysis
        
        Args:
            gray_image: Grayscale face image
            
        Returns:
            True if photo attack detected
        """
        try:
            # Analyze texture using Local Binary Pattern (LBP)
            # Photos typically have different texture patterns than real faces
            
            # Calculate texture variance
            texture_variance = np.var(gray_image)
            
            # Calculate edge density
            edges = cv2.Canny(gray_image, 50, 150)
            edge_density = np.sum(edges > 0) / edges.size
            
            # Photo attacks typically have lower texture variance and edge density
            if texture_variance < 1000 and edge_density < 0.1:
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error detecting photo attack: {e}")
            return False
    
    def detect_video_attack(self, face_image: np.ndarray) -> bool:
        """
        Detect video attack (screen replay)
        
        Args:
            face_image: Face image
            
        Returns:
            True if video attack detected
        """
        try:
            # Convert to HSV for better color analysis
            hsv = cv2.cvtColor(face_image, cv2.COLOR_BGR2HSV)
            
            # Analyze color distribution
            # Video attacks often have different color characteristics
            h_mean = np.mean(hsv[:, :, 0])
            s_mean = np.mean(hsv[:, :, 1])
            v_mean = np.mean(hsv[:, :, 2])
            
            # Video attacks typically have different HSV characteristics
            if s_mean < 30 and v_mean > 200:  # Low saturation, high brightness
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error detecting video attack: {e}")
            return False
    
    def detect_mask_attack(self, face_image: np.ndarray) -> bool:
        """
        Detect mask attack
        
        Args:
            face_image: Face image
            
        Returns:
            True if mask attack detected
        """
        try:
            # Analyze depth information (simplified)
            # Real faces have natural depth variations
            
            # Convert to grayscale
            gray = cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY)
            
            # Calculate depth-like features using gradients
            grad_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
            grad_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
            gradient_magnitude = np.sqrt(grad_x**2 + grad_y**2)
            
            # Masks typically have different gradient patterns
            gradient_variance = np.var(gradient_magnitude)
            
            if gradient_variance < 500:  # Low gradient variance indicates mask
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error detecting mask attack: {e}")
            return False
    
    def detect_3d_mask(self, face_image: np.ndarray) -> bool:
        """
        Detect 3D mask attack
        
        Args:
            face_image: Face image
            
        Returns:
            True if 3D mask detected
        """
        try:
            # Analyze 3D characteristics
            # 3D masks have different lighting and shadow patterns
            
            # Convert to grayscale
            gray = cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY)
            
            # Analyze lighting patterns
            # Real faces have natural lighting variations
            lighting_variance = np.var(gray)
            
            # 3D masks often have more uniform lighting
            if lighting_variance < 800:
                return True
            
            return False
            
        except Exception as e:
            logger.error(f"Error detecting 3D mask: {e}")
            return False
    
    def comprehensive_spoof_detection(self, face_image: np.ndarray) -> Dict[str, Any]:
        """
        Comprehensive spoof detection with multiple checks
        
        Args:
            face_image: Face image
            
        Returns:
            Comprehensive spoof detection results
        """
        try:
            # Primary spoof detection
            is_spoof, confidence, spoof_type = self.detect_spoof(face_image)
            
            # Additional checks
            photo_attack = self.detect_photo_attack(cv2.cvtColor(face_image, cv2.COLOR_BGR2GRAY))
            video_attack = self.detect_video_attack(face_image)
            mask_attack = self.detect_mask_attack(face_image)
            mask_3d_attack = self.detect_3d_mask(face_image)
            
            # Calculate overall risk score
            risk_factors = [photo_attack, video_attack, mask_attack, mask_3d_attack]
            risk_score = sum(risk_factors) / len(risk_factors)
            
            results = {
                'is_spoof': is_spoof,
                'confidence': confidence,
                'spoof_type': spoof_type,
                'risk_score': risk_score,
                'photo_attack': photo_attack,
                'video_attack': video_attack,
                'mask_attack': mask_attack,
                'mask_3d_attack': mask_3d_attack,
                'is_high_risk': risk_score > 0.5 or confidence > settings.ANTI_SPOOF_THRESHOLD
            }
            
            return results
            
        except Exception as e:
            logger.error(f"Error in comprehensive spoof detection: {e}")
            return {
                'is_spoof': True,
                'confidence': 1.0,
                'spoof_type': 'detection_error',
                'risk_score': 1.0,
                'photo_attack': False,
                'video_attack': False,
                'mask_attack': False,
                'mask_3d_attack': False,
                'is_high_risk': True
            }
    
    def get_anti_spoof_statistics(self) -> Dict[str, Any]:
        """
        Get anti-spoofing statistics
        
        Returns:
            Statistics dictionary
        """
        return {
            'model_device': str(self.device),
            'spoof_threshold': settings.ANTI_SPOOF_THRESHOLD,
            'model_loaded': self.spoof_model is not None,
            'supported_attacks': ['photo', 'video', 'mask', '3d_mask'],
            'enabled': settings.ENABLE_ANTI_SPOOF
        }
