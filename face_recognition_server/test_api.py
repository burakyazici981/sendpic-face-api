"""
Basit test API'si - yüz tanıma servisini test etmek için
"""
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import cv2
import numpy as np
import logging
from pathlib import Path
import uuid

# Logging ayarla
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI uygulaması oluştur
app = FastAPI(
    title="SendPic Face Recognition Test API",
    version="1.0.0",
    description="Test API for face recognition features"
)

# CORS middleware ekle
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Upload klasörü oluştur
upload_dir = Path("uploads")
upload_dir.mkdir(exist_ok=True)

@app.get("/")
async def root():
    """Ana endpoint"""
    return {
        "message": "SendPic Face Recognition Test API çalışıyor!",
        "version": "1.0.0",
        "status": "healthy"
    }

@app.get("/health")
async def health_check():
    """Sağlık kontrolü"""
    return {
        "status": "healthy",
        "opencv_version": cv2.__version__,
        "numpy_version": np.__version__
    }

@app.post("/test/upload")
async def test_upload(file: UploadFile = File(...)):
    """Dosya yükleme testi"""
    try:
        # Dosya türünü kontrol et
        if not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="Dosya bir resim olmalı")
        
        # Dosyayı kaydet
        file_id = str(uuid.uuid4())
        file_extension = Path(file.filename).suffix
        file_path = upload_dir / f"{file_id}{file_extension}"
        
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # OpenCV ile resmi oku
        image = cv2.imread(str(file_path))
        if image is None:
            raise HTTPException(status_code=400, detail="Resim okunamadı")
        
        # Temel bilgileri al
        height, width = image.shape[:2]
        
        # Dosyayı temizle
        try:
            file_path.unlink()
        except:
            pass
        
        return {
            "success": True,
            "message": "Dosya başarıyla yüklendi ve işlendi",
            "file_info": {
                "original_filename": file.filename,
                "content_type": file.content_type,
                "file_size": len(content),
                "image_dimensions": {
                    "width": width,
                    "height": height
                }
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Dosya yükleme hatası: {e}")
        raise HTTPException(status_code=500, detail=f"Sunucu hatası: {str(e)}")

@app.post("/test/face-detection")
async def test_face_detection(file: UploadFile = File(...)):
    """Basit yüz tespiti testi"""
    try:
        # Dosya türünü kontrol et
        if not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="Dosya bir resim olmalı")
        
        # Dosyayı kaydet
        file_id = str(uuid.uuid4())
        file_extension = Path(file.filename).suffix
        file_path = upload_dir / f"{file_id}{file_extension}"
        
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # OpenCV ile resmi oku
        image = cv2.imread(str(file_path))
        if image is None:
            raise HTTPException(status_code=400, detail="Resim okunamadı")
        
        # Gri tonlamaya çevir
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Haar Cascade ile yüz tespiti (basit yöntem)
        face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        faces = face_cascade.detectMultiScale(gray, 1.1, 4)
        
        # Sonuçları hazırla
        detected_faces = []
        for (x, y, w, h) in faces:
            detected_faces.append({
                "bbox": [int(x), int(y), int(x + w), int(y + h)],
                "width": int(w),
                "height": int(h),
                "confidence": 0.8  # Haar cascade güven skoru vermez, sabit değer
            })
        
        # Dosyayı temizle
        try:
            file_path.unlink()
        except:
            pass
        
        return {
            "success": True,
            "message": f"{len(detected_faces)} yüz tespit edildi",
            "faces_detected": len(detected_faces),
            "faces": detected_faces,
            "image_info": {
                "width": image.shape[1],
                "height": image.shape[0],
                "channels": image.shape[2] if len(image.shape) > 2 else 1
            }
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Yüz tespiti hatası: {e}")
        raise HTTPException(status_code=500, detail=f"Sunucu hatası: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
