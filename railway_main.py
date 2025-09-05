#!/usr/bin/env python3
"""
Railway için basitleştirilmiş yüz tanıma API
"""

import os
import sys
import asyncio
from pathlib import Path

# Face recognition server dizinini path'e ekle
sys.path.append(str(Path(__file__).parent / "face_recognition_server"))

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import cv2
import numpy as np
from PIL import Image
import io
import base64
import json

app = FastAPI(
    title="SendPic Face Recognition API",
    description="Basit yüz tanıma API'si",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class FaceDetectionResult(BaseModel):
    faces_detected: int
    face_locations: list
    confidence_scores: list
    success: bool
    message: str

class HealthResponse(BaseModel):
    status: str
    version: str
    message: str

# Basit yüz tespiti fonksiyonu
def detect_faces_simple(image_data):
    """Basit yüz tespiti"""
    try:
        # OpenCV ile yüz tespiti
        face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        
        # Görüntüyü yükle
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            return FaceDetectionResult(
                faces_detected=0,
                face_locations=[],
                confidence_scores=[],
                success=False,
                message="Görüntü yüklenemedi"
            )
        
        # Gri tonlamaya çevir
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Yüzleri tespit et
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30)
        )
        
        face_locations = []
        confidence_scores = []
        
        for (x, y, w, h) in faces:
            face_locations.append({
                "x": int(x),
                "y": int(y),
                "width": int(w),
                "height": int(h)
            })
            confidence_scores.append(0.8)  # Basit güven skoru
        
        return FaceDetectionResult(
            faces_detected=len(faces),
            face_locations=face_locations,
            confidence_scores=confidence_scores,
            success=True,
            message=f"{len(faces)} yüz tespit edildi"
        )
        
    except Exception as e:
        return FaceDetectionResult(
            faces_detected=0,
            face_locations=[],
            confidence_scores=[],
            success=False,
            message=f"Hata: {str(e)}"
        )

@app.get("/", response_model=HealthResponse)
async def root():
    """Ana endpoint"""
    return HealthResponse(
        status="ok",
        version="1.0.0",
        message="SendPic Face Recognition API çalışıyor"
    )

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Sağlık kontrolü"""
    return HealthResponse(
        status="healthy",
        version="1.0.0",
        message="API sağlıklı"
    )

@app.post("/detect-faces", response_model=FaceDetectionResult)
async def detect_faces(file: UploadFile = File(...)):
    """Yüz tespiti endpoint'i"""
    try:
        # Dosya boyutunu kontrol et (10MB max)
        if file.size and file.size > 10 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Dosya çok büyük (max 10MB)")
        
        # Görüntü verisini oku
        image_data = await file.read()
        
        # Yüz tespiti yap
        result = detect_faces_simple(image_data)
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sunucu hatası: {str(e)}")

@app.post("/recognize-faces", response_model=FaceDetectionResult)
async def recognize_faces(file: UploadFile = File(...)):
    """Yüz tanıma endpoint'i (şimdilik sadece tespit)"""
    try:
        # Şimdilik sadece yüz tespiti yap
        return await detect_faces(file)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sunucu hatası: {str(e)}")

@app.post("/verify-identity", response_model=FaceDetectionResult)
async def verify_identity(file: UploadFile = File(...)):
    """Kimlik doğrulama endpoint'i (şimdilik sadece tespit)"""
    try:
        # Şimdilik sadece yüz tespiti yap
        return await detect_faces(file)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sunucu hatası: {str(e)}")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(
        "railway_main:app",
        host="0.0.0.0",
        port=port,
        reload=False
    )
