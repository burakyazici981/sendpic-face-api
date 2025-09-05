"""
Configuration settings for Face Recognition Server
"""
import os
from pathlib import Path
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # API Settings
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "SendPic Face Recognition API"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "Advanced face recognition, gender detection, and anti-spoofing API"
    
    # Server Settings
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True
    
    # Database Settings
    DATABASE_URL: str = "sqlite:///./face_recognition.db"
    POSTGRES_USER: Optional[str] = None
    POSTGRES_PASSWORD: Optional[str] = None
    POSTGRES_SERVER: Optional[str] = None
    POSTGRES_PORT: Optional[str] = None
    POSTGRES_DB: Optional[str] = None
    
    # Model Settings
    MODELS_DIR: str = "models"
    FACE_RECOGNITION_MODEL: str = "facenet"
    GENDER_MODEL: str = "gender_classifier"
    ANTI_SPOOF_MODEL: str = "anti_spoof"
    YOLO_MODEL: str = "yolov8n.pt"
    
    # Face Recognition Settings
    FACE_DETECTION_CONFIDENCE: float = 0.5
    FACE_RECOGNITION_THRESHOLD: float = 0.6
    MAX_FACES_PER_IMAGE: int = 10
    
    # Anti-Spoofing Settings
    ANTI_SPOOF_THRESHOLD: float = 0.5
    ENABLE_ANTI_SPOOF: bool = True
    
    # Gender Detection Settings
    GENDER_CONFIDENCE_THRESHOLD: float = 0.7
    ENABLE_GENDER_DETECTION: bool = True
    
    # File Upload Settings
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    ALLOWED_EXTENSIONS: list = [".jpg", ".jpeg", ".png", ".bmp", ".tiff"]
    UPLOAD_DIR: str = "uploads"
    
    # Security Settings
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ALGORITHM: str = "HS256"
    
    # Logging
    LOG_LEVEL: str = "INFO"
    LOG_FILE: str = "logs/face_recognition.log"
    
    # OpenVINO Settings
    OPENVINO_DEVICE: str = "CPU"  # CPU, GPU, AUTO
    ENABLE_OPENVINO: bool = True
    
    class Config:
        env_file = ".env"
        case_sensitive = True

# Create settings instance
settings = Settings()

# Create necessary directories
def create_directories():
    """Create necessary directories if they don't exist"""
    directories = [
        settings.MODELS_DIR,
        settings.UPLOAD_DIR,
        "logs",
        "database",
        "temp"
    ]
    
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)

# Initialize directories
create_directories()
