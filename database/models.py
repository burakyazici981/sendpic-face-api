"""
Database models for Face Recognition System
"""
from sqlalchemy import Column, Integer, String, DateTime, Float, Boolean, Text, LargeBinary
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func
from datetime import datetime
import json

Base = declarative_base()

class User(Base):
    """User model for storing user information"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    name = Column(String(255), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    is_active = Column(Boolean, default=True)
    
    # Relationship with face embeddings
    face_embeddings = relationship("FaceEmbedding", back_populates="user")

class FaceEmbedding(Base):
    """Face embedding model for storing face recognition data"""
    __tablename__ = "face_embeddings"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), index=True, nullable=False)
    embedding = Column(LargeBinary, nullable=False)  # Face embedding vector
    face_image_path = Column(String(500), nullable=True)  # Path to face image
    face_bbox = Column(Text, nullable=True)  # JSON string of bounding box coordinates
    confidence = Column(Float, nullable=False)
    gender = Column(String(10), nullable=True)  # 'male', 'female', 'unknown'
    gender_confidence = Column(Float, nullable=True)
    age_estimate = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationship with user
    user = relationship("User", back_populates="face_embeddings")

class FaceRecognitionLog(Base):
    """Log model for face recognition attempts"""
    __tablename__ = "face_recognition_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), index=True, nullable=True)  # Null if unknown face
    recognized_user_id = Column(String(100), index=True, nullable=True)
    input_image_path = Column(String(500), nullable=False)
    confidence = Column(Float, nullable=False)
    is_spoof = Column(Boolean, default=False)
    spoof_confidence = Column(Float, nullable=True)
    gender = Column(String(10), nullable=True)
    gender_confidence = Column(Float, nullable=True)
    processing_time = Column(Float, nullable=False)  # Processing time in seconds
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class AntiSpoofLog(Base):
    """Anti-spoofing detection logs"""
    __tablename__ = "anti_spoof_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), index=True, nullable=True)
    input_image_path = Column(String(500), nullable=False)
    is_spoof = Column(Boolean, nullable=False)
    spoof_confidence = Column(Float, nullable=False)
    spoof_type = Column(String(50), nullable=True)  # 'photo', 'video', 'mask', etc.
    processing_time = Column(Float, nullable=False)
    ip_address = Column(String(45), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class GenderDetectionLog(Base):
    """Gender detection logs"""
    __tablename__ = "gender_detection_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), index=True, nullable=True)
    input_image_path = Column(String(500), nullable=False)
    detected_gender = Column(String(10), nullable=False)  # 'male', 'female'
    confidence = Column(Float, nullable=False)
    age_estimate = Column(Integer, nullable=True)
    processing_time = Column(Float, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class ModelPerformance(Base):
    """Model performance tracking"""
    __tablename__ = "model_performance"
    
    id = Column(Integer, primary_key=True, index=True)
    model_name = Column(String(100), nullable=False)
    model_version = Column(String(50), nullable=False)
    accuracy = Column(Float, nullable=True)
    precision = Column(Float, nullable=True)
    recall = Column(Float, nullable=True)
    f1_score = Column(Float, nullable=True)
    inference_time = Column(Float, nullable=False)
    test_date = Column(DateTime(timezone=True), server_default=func.now())
    test_data_size = Column(Integer, nullable=True)

# Import relationship after Base is defined
from sqlalchemy.orm import relationship
