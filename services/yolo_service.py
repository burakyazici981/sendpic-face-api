"""
YOLO Service for object detection and face detection
"""
import cv2
import numpy as np
from ultralytics import YOLO
from typing import List, Tuple, Optional, Dict, Any
import logging
from pathlib import Path
from config import settings

logger = logging.getLogger(__name__)

class YOLOService:
    """
    YOLO service for object detection and face detection
    """
    
    def __init__(self):
        self.face_model = None
        self.object_model = None
        self.load_models()
    
    def load_models(self):
        """Load YOLO models"""
        try:
            # Load YOLO face detection model
            face_model_path = Path(settings.MODELS_DIR) / "yolov8n-face.pt"
            if face_model_path.exists():
                self.face_model = YOLO(str(face_model_path))
                logger.info("YOLO face detection model loaded")
            else:
                # Use general YOLO model for face detection
                self.face_model = YOLO(settings.YOLO_MODEL)
                logger.info("YOLO general model loaded for face detection")
            
            # Load YOLO object detection model
            self.object_model = YOLO(settings.YOLO_MODEL)
            logger.info("YOLO object detection model loaded")
            
        except Exception as e:
            logger.error(f"Error loading YOLO models: {e}")
            raise
    
    def detect_faces_yolo(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """
        Detect faces using YOLO
        
        Args:
            image: Input image
            
        Returns:
            List of detected faces
        """
        try:
            # Run YOLO inference
            results = self.face_model(image, conf=settings.FACE_DETECTION_CONFIDENCE)
            
            faces = []
            for result in results:
                boxes = result.boxes
                if boxes is not None:
                    for box in boxes:
                        # Get bounding box coordinates
                        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                        confidence = box.conf[0].cpu().numpy()
                        class_id = int(box.cls[0].cpu().numpy())
                        
                        # Filter for face class (class 0 in COCO dataset)
                        if class_id == 0 and confidence > settings.FACE_DETECTION_CONFIDENCE:
                            face_data = {
                                'bbox': [float(x1), float(y1), float(x2), float(y2)],
                                'confidence': float(confidence),
                                'class_id': class_id,
                                'class_name': 'face'
                            }
                            faces.append(face_data)
            
            return faces
            
        except Exception as e:
            logger.error(f"Error detecting faces with YOLO: {e}")
            return []
    
    def detect_objects(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """
        Detect objects using YOLO
        
        Args:
            image: Input image
            
        Returns:
            List of detected objects
        """
        try:
            # Run YOLO inference
            results = self.object_model(image, conf=0.5)
            
            objects = []
            for result in results:
                boxes = result.boxes
                if boxes is not None:
                    for box in boxes:
                        # Get bounding box coordinates
                        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                        confidence = box.conf[0].cpu().numpy()
                        class_id = int(box.cls[0].cpu().numpy())
                        
                        # Get class name
                        class_name = self.object_model.names[class_id]
                        
                        object_data = {
                            'bbox': [float(x1), float(y1), float(x2), float(y2)],
                            'confidence': float(confidence),
                            'class_id': class_id,
                            'class_name': class_name
                        }
                        objects.append(object_data)
            
            return objects
            
        except Exception as e:
            logger.error(f"Error detecting objects with YOLO: {e}")
            return []
    
    def detect_persons(self, image: np.ndarray) -> List[Dict[str, Any]]:
        """
        Detect persons using YOLO
        
        Args:
            image: Input image
            
        Returns:
            List of detected persons
        """
        try:
            # Run YOLO inference
            results = self.object_model(image, conf=0.5)
            
            persons = []
            for result in results:
                boxes = result.boxes
                if boxes is not None:
                    for box in boxes:
                        # Get bounding box coordinates
                        x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                        confidence = box.conf[0].cpu().numpy()
                        class_id = int(box.cls[0].cpu().numpy())
                        
                        # Filter for person class (class 0 in COCO dataset)
                        if class_id == 0:
                            person_data = {
                                'bbox': [float(x1), float(y1), float(x2), float(y2)],
                                'confidence': float(confidence),
                                'class_id': class_id,
                                'class_name': 'person'
                            }
                            persons.append(person_data)
            
            return persons
            
        except Exception as e:
            logger.error(f"Error detecting persons with YOLO: {e}")
            return []
    
    def extract_face_from_bbox(self, image: np.ndarray, bbox: List[float]) -> Optional[np.ndarray]:
        """
        Extract face region from bounding box
        
        Args:
            image: Input image
            bbox: Bounding box [x1, y1, x2, y2]
            
        Returns:
            Extracted face image or None
        """
        try:
            x1, y1, x2, y2 = map(int, bbox)
            
            # Ensure coordinates are within image bounds
            h, w = image.shape[:2]
            x1 = max(0, min(x1, w))
            y1 = max(0, min(y1, h))
            x2 = max(0, min(x2, w))
            y2 = max(0, min(y2, h))
            
            # Extract face region
            face_region = image[y1:y2, x1:x2]
            
            if face_region.size == 0:
                return None
            
            return face_region
            
        except Exception as e:
            logger.error(f"Error extracting face from bbox: {e}")
            return None
    
    def process_image_with_yolo(self, image_path: str) -> Dict[str, Any]:
        """
        Process image with YOLO for comprehensive detection
        
        Args:
            image_path: Path to input image
            
        Returns:
            YOLO detection results
        """
        try:
            # Load image
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not load image: {image_path}")
            
            # Detect faces
            faces = self.detect_faces_yolo(image)
            
            # Detect persons
            persons = self.detect_persons(image)
            
            # Detect all objects
            objects = self.detect_objects(image)
            
            results = {
                'image_path': image_path,
                'faces_detected': len(faces),
                'persons_detected': len(persons),
                'objects_detected': len(objects),
                'faces': faces,
                'persons': persons,
                'objects': objects
            }
            
            return results
            
        except Exception as e:
            logger.error(f"Error processing image with YOLO: {e}")
            return {
                'image_path': image_path,
                'error': str(e),
                'faces_detected': 0,
                'persons_detected': 0,
                'objects_detected': 0,
                'faces': [],
                'persons': [],
                'objects': []
            }
    
    def get_yolo_statistics(self) -> Dict[str, Any]:
        """
        Get YOLO service statistics
        
        Returns:
            Statistics dictionary
        """
        return {
            'face_model_loaded': self.face_model is not None,
            'object_model_loaded': self.object_model is not None,
            'face_detection_threshold': settings.FACE_DETECTION_CONFIDENCE,
            'supported_classes': list(self.object_model.names.values()) if self.object_model else [],
            'model_path': settings.YOLO_MODEL
        }
