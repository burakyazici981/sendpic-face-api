"""
Pydantic schemas for API requests and responses
"""
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime

class FaceAnalysis(BaseModel):
    """Face analysis result"""
    face_id: int
    bbox: List[float] = Field(..., description="Bounding box coordinates [x1, y1, x2, y2]")
    detection_confidence: float = Field(..., ge=0, le=1, description="Face detection confidence")
    detection_method: str = Field(..., description="Detection method used")
    overall_confidence: float = Field(..., ge=0, le=1, description="Overall confidence score")
    
    # Face Recognition
    face_recognition: Dict[str, Any] = Field(..., description="Face recognition results")
    
    # Gender Detection
    gender_detection: Dict[str, Any] = Field(..., description="Gender detection results")
    
    # Anti-Spoofing
    anti_spoof: Dict[str, Any] = Field(..., description="Anti-spoofing results")
    
    success: bool = Field(..., description="Analysis success status")
    error: Optional[str] = Field(None, description="Error message if any")

class FaceRecognitionRequest(BaseModel):
    """Request model for face recognition"""
    user_id: Optional[str] = Field(None, description="User ID for logging")
    enable_anti_spoof: bool = Field(True, description="Enable anti-spoofing detection")
    enable_gender_detection: bool = Field(True, description="Enable gender detection")

class FaceRecognitionResponse(BaseModel):
    """Response model for face recognition"""
    success: bool = Field(..., description="Request success status")
    image_path: str = Field(..., description="Path to processed image")
    faces_detected: int = Field(..., ge=0, description="Number of faces detected")
    faces_analyzed: List[FaceAnalysis] = Field(..., description="Detailed face analysis results")
    overall_risk_score: float = Field(..., ge=0, le=1, description="Overall risk score")
    processing_time: float = Field(..., ge=0, description="Processing time in seconds")
    error: Optional[str] = Field(None, description="Error message if any")

class AddFaceRequest(BaseModel):
    """Request model for adding a face"""
    user_id: str = Field(..., min_length=1, description="User ID")
    name: Optional[str] = Field(None, description="User name")
    email: Optional[str] = Field(None, description="User email")

class AddFaceResponse(BaseModel):
    """Response model for adding a face"""
    success: bool = Field(..., description="Request success status")
    user_id: str = Field(..., description="User ID")
    message: str = Field(..., description="Response message")
    face_analysis: Optional[FaceAnalysis] = Field(None, description="Face analysis results")
    error: Optional[str] = Field(None, description="Error message if any")

class ServiceStatsResponse(BaseModel):
    """Response model for service statistics"""
    success: bool = Field(..., description="Request success status")
    statistics: Dict[str, Any] = Field(..., description="Service statistics")

class HealthCheckResponse(BaseModel):
    """Response model for health check"""
    message: str = Field(..., description="Health check message")
    version: str = Field(..., description="API version")
    status: str = Field(..., description="Service status")
    services: Optional[Dict[str, Any]] = Field(None, description="Service details")

class FaceRecognitionLog(BaseModel):
    """Face recognition log entry"""
    id: int
    user_id: Optional[str]
    recognized_user_id: Optional[str]
    input_image_path: str
    confidence: float
    is_spoof: bool
    spoof_confidence: Optional[float]
    gender: Optional[str]
    gender_confidence: Optional[float]
    processing_time: float
    ip_address: Optional[str]
    user_agent: Optional[str]
    created_at: datetime

class AntiSpoofLog(BaseModel):
    """Anti-spoofing log entry"""
    id: int
    user_id: Optional[str]
    input_image_path: str
    is_spoof: bool
    spoof_confidence: float
    spoof_type: Optional[str]
    processing_time: float
    ip_address: Optional[str]
    created_at: datetime

class GenderDetectionLog(BaseModel):
    """Gender detection log entry"""
    id: int
    user_id: Optional[str]
    input_image_path: str
    detected_gender: str
    confidence: float
    age_estimate: Optional[int]
    processing_time: float
    created_at: datetime

class User(BaseModel):
    """User model"""
    id: int
    user_id: str
    email: str
    name: str
    created_at: datetime
    updated_at: Optional[datetime]
    is_active: bool

class FaceEmbedding(BaseModel):
    """Face embedding model"""
    id: int
    user_id: str
    face_image_path: Optional[str]
    face_bbox: Optional[str]
    confidence: float
    gender: Optional[str]
    gender_confidence: Optional[float]
    age_estimate: Optional[int]
    created_at: datetime

class ModelPerformance(BaseModel):
    """Model performance tracking"""
    id: int
    model_name: str
    model_version: str
    accuracy: Optional[float]
    precision: Optional[float]
    recall: Optional[float]
    f1_score: Optional[float]
    inference_time: float
    test_date: datetime
    test_data_size: Optional[int]

class ErrorResponse(BaseModel):
    """Error response model"""
    success: bool = Field(False, description="Request success status")
    error: str = Field(..., description="Error message")
    error_code: Optional[str] = Field(None, description="Error code")
    details: Optional[Dict[str, Any]] = Field(None, description="Additional error details")

class BatchProcessRequest(BaseModel):
    """Request model for batch processing"""
    image_paths: List[str] = Field(..., min_items=1, max_items=10, description="List of image paths")
    user_id: Optional[str] = Field(None, description="User ID for logging")
    enable_anti_spoof: bool = Field(True, description="Enable anti-spoofing detection")
    enable_gender_detection: bool = Field(True, description="Enable gender detection")

class BatchProcessResponse(BaseModel):
    """Response model for batch processing"""
    success: bool = Field(..., description="Request success status")
    total_images: int = Field(..., description="Total number of images processed")
    successful_images: int = Field(..., description="Number of successfully processed images")
    failed_images: int = Field(..., description="Number of failed images")
    results: List[FaceRecognitionResponse] = Field(..., description="Results for each image")
    total_processing_time: float = Field(..., description="Total processing time in seconds")
    error: Optional[str] = Field(None, description="Error message if any")
