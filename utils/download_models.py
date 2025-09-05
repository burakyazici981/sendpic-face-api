"""
Script to download and setup required models
"""
import os
import requests
import zipfile
import tarfile
from pathlib import Path
import logging
from config import settings

logger = logging.getLogger(__name__)

def download_file(url: str, destination: Path, description: str = "file"):
    """
    Download a file from URL
    
    Args:
        url: Download URL
        destination: Destination path
        description: Description for logging
    """
    try:
        logger.info(f"Downloading {description} from {url}")
        
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        destination.parent.mkdir(parents=True, exist_ok=True)
        
        with open(destination, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        logger.info(f"Successfully downloaded {description} to {destination}")
        return True
        
    except Exception as e:
        logger.error(f"Error downloading {description}: {e}")
        return False

def download_yolo_models():
    """Download YOLO models"""
    models_dir = Path(settings.MODELS_DIR)
    
    # YOLOv8 models
    yolo_models = [
        {
            "name": "yolov8n.pt",
            "url": "https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt",
            "description": "YOLOv8 Nano model"
        },
        {
            "name": "yolov8s.pt", 
            "url": "https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8s.pt",
            "description": "YOLOv8 Small model"
        },
        {
            "name": "yolov8m.pt",
            "url": "https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8m.pt", 
            "description": "YOLOv8 Medium model"
        }
    ]
    
    for model in yolo_models:
        model_path = models_dir / model["name"]
        if not model_path.exists():
            download_file(model["url"], model_path, model["description"])
        else:
            logger.info(f"Model {model['name']} already exists")

def download_face_models():
    """Download face recognition models"""
    models_dir = Path(settings.MODELS_DIR)
    
    # FaceNet model (will be downloaded by facenet-pytorch automatically)
    logger.info("FaceNet model will be downloaded automatically by facenet-pytorch")
    
    # MTCNN model (will be downloaded by facenet-pytorch automatically)
    logger.info("MTCNN model will be downloaded automatically by facenet-pytorch")

def download_gender_model():
    """Download gender detection model"""
    models_dir = Path(settings.MODELS_DIR)
    
    # For now, we'll use a simple CNN that will be trained
    # In production, you would download a pretrained gender classification model
    logger.info("Gender detection model will be initialized with random weights")
    logger.info("For production use, download a pretrained gender classification model")

def download_anti_spoof_model():
    """Download anti-spoofing model"""
    models_dir = Path(settings.MODELS_DIR)
    
    # For now, we'll use a simple CNN that will be trained
    # In production, you would download a pretrained anti-spoofing model
    logger.info("Anti-spoofing model will be initialized with random weights")
    logger.info("For production use, download a pretrained anti-spoofing model")

def download_openvino_models():
    """Download OpenVINO models"""
    models_dir = Path(settings.MODELS_DIR)
    
    # OpenVINO models for face detection
    openvino_models = [
        {
            "name": "face-detection-adas-0001.xml",
            "url": "https://download.01.org/opencv/2021/openvinotoolkit/2021.1/open_model_zoo/models_bin/1/face-detection-adas-0001/FP32/face-detection-adas-0001.xml",
            "description": "OpenVINO Face Detection model (XML)"
        },
        {
            "name": "face-detection-adas-0001.bin",
            "url": "https://download.01.org/opencv/2021/openvinotoolkit/2021.1/open_model_zoo/models_bin/1/face-detection-adas-0001/FP32/face-detection-adas-0001.bin",
            "description": "OpenVINO Face Detection model (BIN)"
        }
    ]
    
    for model in openvino_models:
        model_path = models_dir / model["name"]
        if not model_path.exists():
            download_file(model["url"], model_path, model["description"])
        else:
            logger.info(f"Model {model['name']} already exists")

def setup_models():
    """Setup all required models"""
    logger.info("Setting up face recognition models...")
    
    # Create models directory
    models_dir = Path(settings.MODELS_DIR)
    models_dir.mkdir(parents=True, exist_ok=True)
    
    # Download models
    download_yolo_models()
    download_face_models()
    download_gender_model()
    download_anti_spoof_model()
    
    if settings.ENABLE_OPENVINO:
        download_openvino_models()
    
    logger.info("Model setup completed!")

def verify_models():
    """Verify that all required models are available"""
    models_dir = Path(settings.MODELS_DIR)
    
    required_models = [
        "yolov8n.pt"
    ]
    
    missing_models = []
    for model in required_models:
        model_path = models_dir / model
        if not model_path.exists():
            missing_models.append(model)
    
    if missing_models:
        logger.warning(f"Missing models: {missing_models}")
        return False
    else:
        logger.info("All required models are available")
        return True

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    setup_models()
    verify_models()
