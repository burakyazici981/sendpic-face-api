"""
Advanced API for Face Recognition Server with all requested features
"""
from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging
import os
import uuid
from pathlib import Path
from services.advanced_face_service import AdvancedFaceService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="SendPic Advanced Face Recognition API",
    version="2.0.0",
    description="Advanced face recognition, gender detection, and anti-spoofing API for SendPic"
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
face_service = AdvancedFaceService()

# Create necessary directories
upload_dir = Path("uploads")
upload_dir.mkdir(exist_ok=True)

@app.get("/")
async def root():
    """Root endpoint - health check"""
    return {
        "message": "SendPic Advanced Face Recognition API is running",
        "version": "2.0.0",
        "status": "healthy",
        "features": [
            "Face Detection",
            "Face Recognition", 
            "Gender Detection",
            "Age Estimation",
            "Anti-Spoofing",
            "Eye Detection"
        ]
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        stats = face_service.get_service_stats()
        return {
            "message": "All services are operational",
            "version": "2.0.0",
            "status": "healthy",
            "services": stats
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            "message": f"Service error: {str(e)}",
            "version": "2.0.0",
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
    """Advanced face recognition with all features"""
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
        
        # Process image with advanced analysis
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
        logger.error(f"Error in face recognition: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/v1/add-face")
async def add_face(
    file: UploadFile = File(...),
    user_id: str = Form(...),
    user_name: str = Form(...)
):
    """Add a new face to the database"""
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
        
        # Add face to database
        result = face_service.add_face(str(file_path), user_id, user_name)
        
        # Clean up uploaded file
        try:
            os.remove(file_path)
        except:
            pass
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error adding face: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/api/v1/faces")
async def get_known_faces():
    """Get list of known faces"""
    try:
        faces = face_service.get_known_faces()
        return {
            "success": True,
            "faces": faces
        }
    except Exception as e:
        logger.error(f"Error getting known faces: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.delete("/api/v1/faces/{user_id}")
async def delete_face(user_id: str):
    """Delete a face from the database"""
    try:
        success = face_service.delete_face(user_id)
        if success:
            return {
                "success": True,
                "message": f"Face for user {user_id} deleted successfully",
                "user_id": user_id
            }
        else:
            raise HTTPException(status_code=404, detail=f"Face for user {user_id} not found")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting face: {e}")
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

@app.post("/api/v1/gender-detection")
async def detect_gender(file: UploadFile = File(...)):
    """Detect gender from face image"""
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
        
        # Extract gender information
        gender_results = []
        for face in results.get('faces', []):
            analysis = face.get('face_analysis', {})
            gender_results.append({
                'face_id': face.get('face_id', 0),
                'gender': analysis.get('gender_estimate', 'unknown'),
                'confidence': analysis.get('gender_confidence', 0.0),
                'age_estimate': analysis.get('age_estimate', None)
            })
        
        # Clean up uploaded file
        try:
            os.remove(file_path)
        except:
            pass
        
        return {
            "success": True,
            "faces_detected": len(gender_results),
            "gender_results": gender_results
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in gender detection: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.post("/api/v1/anti-spoof")
async def anti_spoof_detection(file: UploadFile = File(...)):
    """Anti-spoofing detection"""
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
        
        # Anti-spoofing analysis
        spoof_results = []
        for face in results.get('faces', []):
            analysis = face.get('face_analysis', {})
            
            # Simple anti-spoofing based on face characteristics
            is_spoof = False
            spoof_confidence = 0.0
            spoof_type = "real"
            
            # Check for suspicious characteristics
            if analysis.get('contrast', 0) < 30:  # Low contrast might indicate photo
                is_spoof = True
                spoof_confidence = 0.7
                spoof_type = "photo"
            elif analysis.get('brightness', 0) > 200:  # High brightness might indicate screen
                is_spoof = True
                spoof_confidence = 0.6
                spoof_type = "screen"
            
            spoof_results.append({
                'face_id': face.get('face_id', 0),
                'is_spoof': is_spoof,
                'spoof_confidence': spoof_confidence,
                'spoof_type': spoof_type,
                'risk_score': spoof_confidence
            })
        
        # Clean up uploaded file
        try:
            os.remove(file_path)
        except:
            pass
        
        return {
            "success": True,
            "faces_detected": len(spoof_results),
            "anti_spoof_results": spoof_results
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in anti-spoof detection: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
