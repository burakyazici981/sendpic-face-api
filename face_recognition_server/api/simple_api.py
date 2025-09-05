"""
Simple API for Face Recognition Server
"""
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import logging
import os
import uuid
from pathlib import Path
from services.simple_face_service import SimpleFaceService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="SendPic Face Recognition API",
    version="1.0.0",
    description="Simple face recognition API for SendPic"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
face_service = SimpleFaceService()

# Create upload directory
upload_dir = Path("uploads")
upload_dir.mkdir(exist_ok=True)

@app.get("/")
async def root():
    """Root endpoint - health check"""
    return {
        "message": "SendPic Face Recognition API is running",
        "version": "1.0.0",
        "status": "healthy"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        stats = face_service.get_service_stats()
        return {
            "message": "All services are operational",
            "version": "1.0.0",
            "status": "healthy",
            "services": stats
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            "message": f"Service error: {str(e)}",
            "version": "1.0.0",
            "status": "unhealthy"
        }

@app.post("/test/face-detection")
async def test_face_detection(file: UploadFile = File(...)):
    """Simple face detection test"""
    try:
        # Validate file
        if not file.content_type.startswith('image/'):
            raise HTTPException(status_code=400, detail="File must be an image")
        
        # Save uploaded file
        file_id = str(uuid.uuid4())
        file_extension = Path(file.filename).suffix
        file_path = upload_dir / f"{file_id}{file_extension}"
        
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
        
        # Process image
        results = face_service.detect_faces(str(file_path))
        
        # Clean up uploaded file
        try:
            os.remove(file_path)
        except:
            pass
        
        return results
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in face detection: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/v1/recognize")
async def recognize_faces(file: UploadFile = File(...)):
    """Advanced face recognition"""
    try:
        # For now, use the same simple detection
        return await test_face_detection(file)
    except Exception as e:
        logger.error(f"Error in face recognition: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/v1/stats")
async def get_service_stats():
    """Get service statistics"""
    try:
        stats = face_service.get_service_stats()
        return {
            "success": True,
            "statistics": stats
        }
    except Exception as e:
        logger.error(f"Error getting service stats: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
