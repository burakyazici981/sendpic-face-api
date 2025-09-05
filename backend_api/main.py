from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import httpx
import os
from datetime import datetime

app = FastAPI(title="SendPic Backend API", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Supabase configuration
SUPABASE_URL = "https://tdxfwcgqesvgrdqidxik.supabase.co"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ"

# Pydantic models
class UserRegistration(BaseModel):
    email: str
    password: str
    name: str
    profile_image_url: Optional[str] = None
    gender: Optional[str] = None
    age: Optional[int] = None
    birth_date: Optional[str] = None

class ContentSend(BaseModel):
    content_type: str  # 'photo' or 'video'
    content_url: str
    caption: Optional[str] = None

class TokenUpdate(BaseModel):
    photo_tokens: int
    video_tokens: int
    premium_tokens: int

# Helper function to make Supabase requests
async def make_supabase_request(method: str, endpoint: str, data: dict = None, headers: dict = None):
    url = f"{SUPABASE_URL}/rest/v1/{endpoint}"
    default_headers = {
        "apikey": SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
        "Content-Type": "application/json"
    }
    if headers:
        default_headers.update(headers)
    
    async with httpx.AsyncClient() as client:
        if method == "GET":
            response = await client.get(url, headers=default_headers)
        elif method == "POST":
            response = await client.post(url, headers=default_headers, json=data)
        elif method == "PUT":
            response = await client.put(url, headers=default_headers, json=data)
        elif method == "DELETE":
            response = await client.delete(url, headers=default_headers)
        else:
            raise HTTPException(status_code=400, detail="Invalid method")
        
        return response

# Authentication endpoints
@app.post("/auth/register")
async def register_user(user_data: UserRegistration):
    """Register a new user"""
    try:
        # Register with Supabase Auth
        auth_data = {
            "email": user_data.email,
            "password": user_data.password,
            "data": {
                "name": user_data.name,
                "profile_image_url": user_data.profile_image_url,
                "gender": user_data.gender,
                "age": user_data.age,
                "birth_date": user_data.birth_date
            }
        }
        
        auth_response = await make_supabase_request("POST", "auth/v1/signup", auth_data)
        
        if auth_response.status_code != 200:
            raise HTTPException(status_code=400, detail="Registration failed")
        
        auth_result = auth_response.json()
        user_id = auth_result.get("user", {}).get("id")
        
        if not user_id:
            raise HTTPException(status_code=400, detail="User ID not found")
        
        # Create user profile
        profile_data = {
            "id": user_id,
            "email": user_data.email,
            "name": user_data.name,
            "profile_image_url": user_data.profile_image_url,
            "gender": user_data.gender,
            "age": user_data.age,
            "birth_date": user_data.birth_date,
            "is_verified": True,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        profile_response = await make_supabase_request("POST", "users", profile_data)
        
        if profile_response.status_code not in [200, 201]:
            raise HTTPException(status_code=400, detail="Profile creation failed")
        
        # Create user tokens (1000 each)
        token_data = {
            "user_id": user_id,
            "photo_tokens": 1000,
            "video_tokens": 1000,
            "premium_tokens": 0,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        token_response = await make_supabase_request("POST", "user_tokens", token_data)
        
        if token_response.status_code not in [200, 201]:
            print(f"Warning: Token creation failed for user {user_id}")
        
        return {
            "success": True,
            "user_id": user_id,
            "message": "User registered successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/auth/login")
async def login_user(email: str, password: str):
    """Login user"""
    try:
        auth_data = {
            "email": email,
            "password": password
        }
        
        auth_response = await make_supabase_request("POST", "auth/v1/token?grant_type=password", auth_data)
        
        if auth_response.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        auth_result = auth_response.json()
        user_id = auth_result.get("user", {}).get("id")
        
        if not user_id:
            raise HTTPException(status_code=401, detail="User ID not found")
        
        # Get user profile
        profile_response = await make_supabase_request("GET", f"users?id=eq.{user_id}")
        
        if profile_response.status_code != 200:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        profile_data = profile_response.json()
        if not profile_data:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        user_profile = profile_data[0]
        
        # Get user tokens
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        
        tokens = {}
        if token_response.status_code == 200:
            token_data = token_response.json()
            if token_data:
                tokens = token_data[0]
        
        return {
            "success": True,
            "user": user_profile,
            "tokens": tokens,
            "access_token": auth_result.get("access_token")
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Content management endpoints
@app.post("/content/send")
async def send_content(content: ContentSend, user_id: str = Header(..., alias="X-User-ID")):
    """Send content to random user"""
    try:
        # Check if user has enough tokens
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        
        if token_response.status_code != 200:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        token_data = token_response.json()
        if not token_data:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        user_tokens = token_data[0]
        
        # Check token availability
        if content.content_type == "photo":
            if user_tokens.get("photo_tokens", 0) <= 0:
                raise HTTPException(status_code=400, detail="Insufficient photo tokens")
        elif content.content_type == "video":
            if user_tokens.get("video_tokens", 0) <= 0:
                raise HTTPException(status_code=400, detail="Insufficient video tokens")
        else:
            raise HTTPException(status_code=400, detail="Invalid content type")
        
        # Get random user (excluding sender)
        users_response = await make_supabase_request("GET", f"users?id=neq.{user_id}&select=id")
        
        if users_response.status_code != 200:
            raise HTTPException(status_code=500, detail="Failed to get users")
        
        users = users_response.json()
        if not users:
            raise HTTPException(status_code=400, detail="No recipients available")
        
        import random
        random_user = random.choice(users)
        recipient_id = random_user["id"]
        
        # Create content record
        content_data = {
            "user_id": user_id,
            "content_type": content.content_type,
            "content_url": content.content_url,
            "caption": content.caption,
            "is_public": True,
            "likes_count": 0,
            "comments_count": 0,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        content_response = await make_supabase_request("POST", "posts", content_data)
        
        if content_response.status_code not in [200, 201]:
            raise HTTPException(status_code=500, detail="Failed to create content")
        
        content_result = content_response.json()
        content_id = content_result[0]["id"]
        
        # Create recipient record
        recipient_data = {
            "content_id": content_id,
            "recipient_id": recipient_id,
            "is_liked": False,
            "friend_requested": False,
            "received_at": datetime.now().isoformat()
        }
        
        recipient_response = await make_supabase_request("POST", "content_recipients", recipient_data)
        
        if recipient_response.status_code not in [200, 201]:
            print(f"Warning: Recipient record creation failed for content {content_id}")
        
        # Deduct token
        if content.content_type == "photo":
            new_photo_tokens = user_tokens.get("photo_tokens", 0) - 1
            token_update = {"photo_tokens": new_photo_tokens}
        else:
            new_video_tokens = user_tokens.get("video_tokens", 0) - 1
            token_update = {"video_tokens": new_video_tokens}
        
        token_update["updated_at"] = datetime.now().isoformat()
        
        update_token_response = await make_supabase_request(
            "PATCH", 
            f"user_tokens?user_id=eq.{user_id}", 
            token_update
        )
        
        if update_token_response.status_code not in [200, 204]:
            print(f"Warning: Token update failed for user {user_id}")
        
        return {
            "success": True,
            "content_id": content_id,
            "recipient_id": recipient_id,
            "message": "Content sent successfully"
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/content/received")
async def get_received_content(user_id: str = Header(..., alias="X-User-ID")):
    """Get content received by user"""
    try:
        response = await make_supabase_request(
            "GET", 
            f"content_recipients?recipient_id=eq.{user_id}&select=*,posts(*)"
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail="Failed to get received content")
        
        return {
            "success": True,
            "content": response.json()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/user/tokens")
async def get_user_tokens(user_id: str = Header(..., alias="X-User-ID")):
    """Get user tokens"""
    try:
        response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail="Failed to get user tokens")
        
        token_data = response.json()
        if not token_data:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        return {
            "success": True,
            "tokens": token_data[0]
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
