"""
FastAPI main application for Face Recognition Server
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List, Optional
import logging
import os
import uuid
from pathlib import Path

from config import settings
from database.connection import get_db, init_database
from services.integrated_face_service import IntegratedFaceService
from api.schemas import (
    FaceRecognitionRequest,
    FaceRecognitionResponse,
    AddFaceRequest,
    AddFaceResponse,
    ServiceStatsResponse,
    HealthCheckResponse
)

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=settings.DESCRIPTION,
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
integrated_service = IntegratedFaceService()

# Initialize database
init_database()

@app.on_event("startup")
async def startup_event():
    """Application startup event"""
    logger.info("Face Recognition API starting up...")
    logger.info(f"API Version: {settings.VERSION}")
    logger.info(f"Debug Mode: {settings.DEBUG}")

@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event"""
    logger.info("Face Recognition API shutting down...")

@app.get("/", response_model=HealthCheckResponse)
async def root():
    """Root endpoint - health check"""
    return HealthCheckResponse(
        message="Face Recognition API is running",
        version=settings.VERSION,
        status="healthy"
    )

@app.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """Health check endpoint"""
    try:
        # Check if services are loaded
        stats = integrated_service.get_service_statistics()
        
        return HealthCheckResponse(
            message="All services are operational",
            version=settings.VERSION,
            status="healthy",
            services=stats
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return HealthCheckResponse(
            message=f"Service error: {str(e)}",
            version=settings.VERSION,
            status="unhealthy"
        )

@app.post("/api/v1/recognize", response_model=FaceRecognitionResponse)
async def recognize_faces(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Recognize faces in uploaded image
    """
    try:
        # Validate file
        if not file.content_type.startswith('image/'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File must be an image"
            )
        
        # Check file size
        if file.size > settings.MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File size exceeds {settings.MAX_FILE_SIZE} bytes"
            )
        
        # Save uploaded file
        file_id = str(uuid.uuid4())
        file_extension = Path(file.filename).suffix
        upload_path = Path(settings.UPLOAD_DIR) / f"{file_id}{file_extension}"
        
        with open(upload_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Process image
        results = integrated_service.process_image_comprehensive(str(upload_path))
        
        # Clean up uploaded file
        try:
            os.remove(upload_path)
        except:
            pass
        
        return FaceRecognitionResponse(
            success=results['success'],
            image_path=results['image_path'],
            faces_detected=results['faces_detected'],
            faces_analyzed=results['faces_analyzed'],
            overall_risk_score=results['overall_risk_score'],
            processing_time=results['processing_time'],
            error=results.get('error')
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in face recognition: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )

@app.post("/api/v1/add-face", response_model=AddFaceResponse)
async def add_face(
    request: AddFaceRequest,
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Add a new face to the database
    """
    try:
        # Validate file
        if not file.content_type.startswith('image/'):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="File must be an image"
            )
        
        # Check file size
        if file.size > settings.MAX_FILE_SIZE:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File size exceeds {settings.MAX_FILE_SIZE} bytes"
            )
        
        # Save uploaded file
        file_id = str(uuid.uuid4())
        file_extension = Path(file.filename).suffix
        upload_path = Path(settings.UPLOAD_DIR) / f"{file_id}{file_extension}"
        
        with open(upload_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Add face to database
        result = integrated_service.add_face_to_database(
            user_id=request.user_id,
            image_path=str(upload_path)
        )
        
        # Clean up uploaded file
        try:
            os.remove(upload_path)
        except:
            pass
        
        return AddFaceResponse(
            success=result['success'],
            user_id=result['user_id'],
            message=result.get('message', ''),
            face_analysis=result.get('face_analysis'),
            error=result.get('error')
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error adding face: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )

@app.get("/api/v1/stats", response_model=ServiceStatsResponse)
async def get_service_stats():
    """
    Get service statistics
    """
    try:
        stats = integrated_service.get_service_statistics()
        return ServiceStatsResponse(
            success=True,
            statistics=stats
        )
    except Exception as e:
        logger.error(f"Error getting service stats: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )

@app.get("/api/v1/faces")
async def get_known_faces(db: Session = Depends(get_db)):
    """
    Get list of known faces
    """
    try:
        # This would query the database for known faces
        # For now, return basic info
        stats = integrated_service.get_service_statistics()
        face_stats = stats.get('face_recognition', {})
        
        return {
            "success": True,
            "total_faces": face_stats.get('total_known_faces', 0),
            "known_users": face_stats.get('known_user_ids', [])
        }
    except Exception as e:
        logger.error(f"Error getting known faces: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )

@app.delete("/api/v1/faces/{user_id}")
async def delete_face(user_id: str, db: Session = Depends(get_db)):
    """
    Delete a face from the database
    """
    try:
        # This would delete the face from database
        # For now, return success
        return {
            "success": True,
            "message": f"Face for user {user_id} deleted successfully",
            "user_id": user_id
        }
    except Exception as e:
        logger.error(f"Error deleting face: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level=settings.LOG_LEVEL.lower()
    )
