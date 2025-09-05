"""
Integrated Face Recognition Service combining all face analysis capabilities
"""
import cv2
import numpy as np
import time
from typing import List, Tuple, Optional, Dict, Any
import logging
from pathlib import Path

from services.face_recognition_service import FaceRecognitionService
from services.gender_detection_service import GenderDetectionService
from services.anti_spoof_service import AntiSpoofService
from services.yolo_service import YOLOService
from config import settings

logger = logging.getLogger(__name__)

class IntegratedFaceService:
    """
    Integrated service combining face recognition, gender detection, anti-spoofing, and YOLO
    """
    
    def __init__(self):
        self.face_recognition = FaceRecognitionService()
        self.gender_detection = GenderDetectionService()
        self.anti_spoof = AntiSpoofService()
        self.yolo = YOLOService()
        
        logger.info("Integrated Face Service initialized")
    
    def process_image_comprehensive(self, image_path: str) -> Dict[str, Any]:
        """
        Comprehensive image processing with all services
        
        Args:
            image_path: Path to input image
            
        Returns:
            Comprehensive analysis results
        """
        start_time = time.time()
        
        try:
            # Load image
            image = cv2.imread(image_path)
            if image is None:
                raise ValueError(f"Could not load image: {image_path}")
            
            # Initialize results
            results = {
                'image_path': image_path,
                'processing_time': 0,
                'faces_detected': 0,
                'faces_analyzed': [],
                'overall_risk_score': 0,
                'success': True,
                'error': None
            }
            
            # Step 1: Face Detection (using both MTCNN and YOLO)
            logger.info("Detecting faces...")
            mtcnn_faces = self.face_recognition.detect_faces(image)
            yolo_faces = self.yolo.detect_faces_yolo(image)
            
            # Combine face detections
            all_faces = self._combine_face_detections(mtcnn_faces, yolo_faces)
            results['faces_detected'] = len(all_faces)
            
            if len(all_faces) == 0:
                results['processing_time'] = time.time() - start_time
                return results
            
            # Step 2: Analyze each detected face
            faces_analyzed = []
            risk_scores = []
            
            for i, face in enumerate(all_faces):
                logger.info(f"Analyzing face {i+1}/{len(all_faces)}")
                
                face_analysis = self._analyze_single_face(image, face, i)
                faces_analyzed.append(face_analysis)
                
                # Collect risk scores
                if face_analysis.get('anti_spoof', {}).get('is_spoof', False):
                    risk_scores.append(face_analysis['anti_spoof']['risk_score'])
            
            results['faces_analyzed'] = faces_analyzed
            results['overall_risk_score'] = max(risk_scores) if risk_scores else 0
            
            # Step 3: Calculate processing time
            results['processing_time'] = time.time() - start_time
            
            logger.info(f"Comprehensive analysis completed in {results['processing_time']:.2f}s")
            return results
            
        except Exception as e:
            logger.error(f"Error in comprehensive image processing: {e}")
            return {
                'image_path': image_path,
                'processing_time': time.time() - start_time,
                'faces_detected': 0,
                'faces_analyzed': [],
                'overall_risk_score': 1.0,
                'success': False,
                'error': str(e)
            }
    
    def _combine_face_detections(self, mtcnn_faces: List[Dict], yolo_faces: List[Dict]) -> List[Dict]:
        """
        Combine face detections from different models
        
        Args:
            mtcnn_faces: MTCNN face detections
            yolo_faces: YOLO face detections
            
        Returns:
            Combined face detections
        """
        combined_faces = []
        
        # Add MTCNN faces
        for face in mtcnn_faces:
            face['detection_method'] = 'mtcnn'
            combined_faces.append(face)
        
        # Add YOLO faces (avoid duplicates)
        for yolo_face in yolo_faces:
            is_duplicate = False
            for existing_face in combined_faces:
                if self._is_same_face(yolo_face['bbox'], existing_face['bbox']):
                    is_duplicate = True
                    # Update with higher confidence
                    if yolo_face['confidence'] > existing_face['confidence']:
                        existing_face.update(yolo_face)
                        existing_face['detection_method'] = 'yolo'
                    break
            
            if not is_duplicate:
                yolo_face['detection_method'] = 'yolo'
                combined_faces.append(yolo_face)
        
        return combined_faces
    
    def _is_same_face(self, bbox1: List[float], bbox2: List[float], threshold: float = 0.5) -> bool:
        """
        Check if two bounding boxes represent the same face
        
        Args:
            bbox1: First bounding box
            bbox2: Second bounding box
            threshold: IoU threshold
            
        Returns:
            True if same face
        """
        try:
            # Calculate IoU (Intersection over Union)
            x1_1, y1_1, x2_1, y2_1 = bbox1
            x1_2, y1_2, x2_2, y2_2 = bbox2
            
            # Calculate intersection
            x1_i = max(x1_1, x1_2)
            y1_i = max(y1_1, y1_2)
            x2_i = min(x2_1, x2_2)
            y2_i = min(y2_1, y2_2)
            
            if x2_i <= x1_i or y2_i <= y1_i:
                return False
            
            intersection = (x2_i - x1_i) * (y2_i - y1_i)
            
            # Calculate union
            area1 = (x2_1 - x1_1) * (y2_1 - y1_1)
            area2 = (x2_2 - x1_2) * (y2_2 - y1_2)
            union = area1 + area2 - intersection
            
            iou = intersection / union if union > 0 else 0
            return iou > threshold
            
        except Exception as e:
            logger.error(f"Error calculating IoU: {e}")
            return False
    
    def _analyze_single_face(self, image: np.ndarray, face: Dict[str, Any], face_id: int) -> Dict[str, Any]:
        """
        Analyze a single detected face
        
        Args:
            image: Input image
            face: Face detection data
            face_id: Face identifier
            
        Returns:
            Comprehensive face analysis
        """
        try:
            bbox = face['bbox']
            
            # Extract face region
            face_region = self.yolo.extract_face_from_bbox(image, bbox)
            if face_region is None:
                return {
                    'face_id': face_id,
                    'bbox': bbox,
                    'error': 'Could not extract face region',
                    'success': False
                }
            
            # Initialize analysis result
            analysis = {
                'face_id': face_id,
                'bbox': bbox,
                'detection_confidence': face['confidence'],
                'detection_method': face.get('detection_method', 'unknown'),
                'success': True
            }
            
            # Face Recognition
            logger.info(f"Performing face recognition for face {face_id}")
            embedding = self.face_recognition.extract_face_embedding(image, bbox)
            if embedding is not None:
                user_id, rec_confidence = self.face_recognition.recognize_face(embedding)
                analysis['face_recognition'] = {
                    'user_id': user_id,
                    'confidence': rec_confidence,
                    'is_known': user_id is not None,
                    'embedding_available': True
                }
            else:
                analysis['face_recognition'] = {
                    'user_id': None,
                    'confidence': 0.0,
                    'is_known': False,
                    'embedding_available': False
                }
            
            # Gender Detection
            if settings.ENABLE_GENDER_DETECTION:
                logger.info(f"Performing gender detection for face {face_id}")
                gender_result = self.gender_detection.predict_gender_advanced(face_region)
                analysis['gender_detection'] = gender_result
            else:
                analysis['gender_detection'] = {
                    'gender': 'unknown',
                    'confidence': 0.0,
                    'is_confident': False,
                    'age_estimate': None
                }
            
            # Anti-Spoofing Detection
            if settings.ENABLE_ANTI_SPOOF:
                logger.info(f"Performing anti-spoof detection for face {face_id}")
                spoof_result = self.anti_spoof.comprehensive_spoof_detection(face_region)
                analysis['anti_spoof'] = spoof_result
            else:
                analysis['anti_spoof'] = {
                    'is_spoof': False,
                    'confidence': 0.0,
                    'spoof_type': 'real',
                    'risk_score': 0.0,
                    'is_high_risk': False
                }
            
            # Calculate overall confidence
            analysis['overall_confidence'] = self._calculate_overall_confidence(analysis)
            
            return analysis
            
        except Exception as e:
            logger.error(f"Error analyzing face {face_id}: {e}")
            return {
                'face_id': face_id,
                'bbox': face.get('bbox', []),
                'error': str(e),
                'success': False
            }
    
    def _calculate_overall_confidence(self, analysis: Dict[str, Any]) -> float:
        """
        Calculate overall confidence score for face analysis
        
        Args:
            analysis: Face analysis results
            
        Returns:
            Overall confidence score
        """
        try:
            scores = []
            
            # Detection confidence
            scores.append(analysis.get('detection_confidence', 0.0))
            
            # Face recognition confidence
            if analysis.get('face_recognition', {}).get('is_known', False):
                scores.append(analysis['face_recognition']['confidence'])
            
            # Gender detection confidence
            if analysis.get('gender_detection', {}).get('is_confident', False):
                scores.append(analysis['gender_detection']['confidence'])
            
            # Anti-spoof confidence (inverted - lower spoof confidence = higher real confidence)
            anti_spoof = analysis.get('anti_spoof', {})
            if not anti_spoof.get('is_spoof', False):
                scores.append(1.0 - anti_spoof.get('confidence', 0.0))
            
            # Calculate weighted average
            if scores:
                return sum(scores) / len(scores)
            else:
                return 0.0
                
        except Exception as e:
            logger.error(f"Error calculating overall confidence: {e}")
            return 0.0
    
    def add_face_to_database(self, user_id: str, image_path: str) -> Dict[str, Any]:
        """
        Add a new face to the database
        
        Args:
            user_id: User identifier
            image_path: Path to face image
            
        Returns:
            Addition result
        """
        try:
            # Process image
            results = self.process_image_comprehensive(image_path)
            
            if not results['success'] or results['faces_detected'] == 0:
                return {
                    'success': False,
                    'error': 'No faces detected in image',
                    'user_id': user_id
                }
            
            # Get the best face (highest confidence)
            best_face = max(results['faces_analyzed'], 
                          key=lambda x: x.get('overall_confidence', 0.0))
            
            # Check if face is real (not spoofed)
            if best_face.get('anti_spoof', {}).get('is_spoof', False):
                return {
                    'success': False,
                    'error': 'Face appears to be spoofed',
                    'user_id': user_id,
                    'spoof_type': best_face['anti_spoof']['spoof_type']
                }
            
            # Extract embedding
            embedding = self.face_recognition.extract_face_embedding(
                cv2.imread(image_path), 
                best_face['bbox']
            )
            
            if embedding is None:
                return {
                    'success': False,
                    'error': 'Could not extract face embedding',
                    'user_id': user_id
                }
            
            # Add to database
            success = self.face_recognition.add_face_to_database(
                user_id=user_id,
                embedding=embedding,
                face_image_path=image_path,
                bbox=best_face['bbox'],
                confidence=best_face['detection_confidence']
            )
            
            return {
                'success': success,
                'user_id': user_id,
                'face_analysis': best_face,
                'message': 'Face added successfully' if success else 'Failed to add face'
            }
            
        except Exception as e:
            logger.error(f"Error adding face to database: {e}")
            return {
                'success': False,
                'error': str(e),
                'user_id': user_id
            }
    
    def get_service_statistics(self) -> Dict[str, Any]:
        """
        Get comprehensive service statistics
        
        Returns:
            Statistics dictionary
        """
        return {
            'face_recognition': self.face_recognition.get_face_statistics(),
            'gender_detection': self.gender_detection.get_gender_statistics(),
            'anti_spoof': self.anti_spoof.get_anti_spoof_statistics(),
            'yolo': self.yolo.get_yolo_statistics(),
            'settings': {
                'face_detection_threshold': settings.FACE_DETECTION_CONFIDENCE,
                'face_recognition_threshold': settings.FACE_RECOGNITION_THRESHOLD,
                'anti_spoof_threshold': settings.ANTI_SPOOF_THRESHOLD,
                'gender_confidence_threshold': settings.GENDER_CONFIDENCE_THRESHOLD,
                'enable_anti_spoof': settings.ENABLE_ANTI_SPOOF,
                'enable_gender_detection': settings.ENABLE_GENDER_DETECTION
            }
        }
