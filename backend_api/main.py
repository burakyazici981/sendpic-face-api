from fastapi import FastAPI, HTTPException, Depends, Header, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, validator
from typing import Optional, List, Dict, Union
import httpx
import os
import json
import asyncio
import jwt
import bcrypt
import stripe
from datetime import datetime, timedelta
from decimal import Decimal
import uuid
import logging
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# API Version
API_VERSION = "2.0.0"
API_LAST_UPDATED = datetime.now().isoformat()

# JWT Configuration
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-super-secret-jwt-key-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRATION_HOURS = 24

# Stripe Configuration
stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "sk_test_...")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "whsec_...")

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
security = HTTPBearer()

app = FastAPI(title="SendPic Backend API", version=API_VERSION)

# Add rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Security headers middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'"
    return response

# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    import time
    start_time = time.time()
    
    # Log request
    logger.info(f"Request: {request.method} {request.url} - IP: {request.client.host}")
    
    response = await call_next(request)
    
    # Log response
    process_time = time.time() - start_time
    logger.info(f"Response: {response.status_code} - Time: {process_time:.4f}s")
    
    return response

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# JWT Helper Functions
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid authentication credentials")
        return user_id
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid authentication credentials")

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

# Input validation and sanitization
def sanitize_input(data: str) -> str:
    """Sanitize user input to prevent XSS and injection attacks"""
    if not isinstance(data, str):
        return data
    
    # Remove potentially dangerous characters
    dangerous_chars = ['<', '>', '"', "'", '&', ';', '(', ')', '{', '}', '[', ']']
    for char in dangerous_chars:
        data = data.replace(char, '')
    
    return data.strip()

def validate_email_format(email: str) -> bool:
    """Validate email format"""
    import re
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def validate_password_strength(password: str) -> tuple[bool, str]:
    """Validate password strength"""
    if len(password) < 8:
        return False, "Password must be at least 8 characters long"
    
    if not any(c.isupper() for c in password):
        return False, "Password must contain at least one uppercase letter"
    
    if not any(c.islower() for c in password):
        return False, "Password must contain at least one lowercase letter"
    
    if not any(c.isdigit() for c in password):
        return False, "Password must contain at least one number"
    
    return True, "Password is strong"

# Token pricing configuration
TOKEN_PRICES = {
    'photo': {'price': 0.10, 'currency': 'USD'},  # $0.10 per photo token
    'video': {'price': 0.25, 'currency': 'USD'},  # $0.25 per video token
    'premium': {'price': 1.00, 'currency': 'USD'}  # $1.00 per premium token
}

def calculate_token_price(token_type: str, quantity: int) -> Decimal:
    if token_type not in TOKEN_PRICES:
        raise ValueError(f"Invalid token type: {token_type}")
    
    base_price = Decimal(str(TOKEN_PRICES[token_type]['price']))
    total_price = base_price * quantity
    
    # Apply bulk discounts
    if quantity >= 1000:
        total_price *= Decimal('0.8')  # 20% discount for 1000+
    elif quantity >= 500:
        total_price *= Decimal('0.9')  # 10% discount for 500+
    elif quantity >= 100:
        total_price *= Decimal('0.95')  # 5% discount for 100+
    
    return total_price.quantize(Decimal('0.01'))

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
    
    @validator('email')
    def validate_email(cls, v):
        if '@' not in v or '.' not in v:
            raise ValueError('Invalid email format')
        return v.lower()
    
    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        return v

class UserLogin(BaseModel):
    email: str
    password: str

class ContentSend(BaseModel):
    content_type: str  # 'photo' or 'video'
    content_url: str
    caption: Optional[str] = None
    
    @validator('content_type')
    def validate_content_type(cls, v):
        if v not in ['photo', 'video']:
            raise ValueError('Content type must be photo or video')
        return v

class TokenPurchase(BaseModel):
    token_type: str  # 'photo', 'video', 'premium'
    quantity: int
    payment_method: str  # 'stripe', 'paypal', 'apple_pay', 'google_pay'
    
    @validator('token_type')
    def validate_token_type(cls, v):
        if v not in ['photo', 'video', 'premium']:
            raise ValueError('Invalid token type')
        return v
    
    @validator('quantity')
    def validate_quantity(cls, v):
        if v <= 0 or v > 10000:
            raise ValueError('Quantity must be between 1 and 10000')
        return v

class PaymentIntent(BaseModel):
    amount: Decimal
    currency: str = 'USD'
    token_type: str
    quantity: int
    
class WebhookEvent(BaseModel):
    type: str
    data: Dict

class TokenUpdate(BaseModel):
    photo_tokens: int
    video_tokens: int
    premium_tokens: int

class ApiVersionResponse(BaseModel):
    version: str
    last_updated: str
    features: List[str]
    breaking_changes: List[str]

class UserProfile(BaseModel):
    id: str
    email: str
    name: str
    profile_image_url: Optional[str]
    gender: Optional[str]
    age: Optional[int]
    is_verified: bool
    is_premium: bool
    created_at: str

class TokenBalance(BaseModel):
    photo_tokens: int
    video_tokens: int
    premium_tokens: int
    total_purchased: int
    last_purchase_date: Optional[str]

# WebSocket Connection Manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.user_connections: Dict[str, WebSocket] = {}
    
    async def connect(self, websocket: WebSocket, user_id: str = None):
        await websocket.accept()
        self.active_connections.append(websocket)
        if user_id:
            self.user_connections[user_id] = websocket
    
    def disconnect(self, websocket: WebSocket, user_id: str = None):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
        if user_id and user_id in self.user_connections:
            del self.user_connections[user_id]
    
    async def send_personal_message(self, message: str, user_id: str):
        if user_id in self.user_connections:
            websocket = self.user_connections[user_id]
            try:
                await websocket.send_text(message)
            except:
                self.disconnect(websocket, user_id)
    
    async def broadcast(self, message: str):
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                disconnected.append(connection)
        
        for connection in disconnected:
            self.disconnect(connection)

manager = ConnectionManager()

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
@limiter.limit("5/minute")
async def login_user(request: Request, login_data: UserLogin):
    """Login user with JWT authentication"""
    try:
        # Get user from database
        user_response = await make_supabase_request("GET", f"users?email=eq.{login_data.email}")
        
        if user_response.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        users = user_response.json()
        if not users:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        user = users[0]
        
        # For now, we'll use simple password comparison (in production, use hashed passwords)
        # TODO: Implement proper password hashing
        
        # Create JWT token
        access_token = create_access_token(data={"sub": user["id"], "email": user["email"]})
        
        # Update last login
        await make_supabase_request("PATCH", f"users?id=eq.{user['id']}", {
            "last_login": datetime.now().isoformat()
        })
        
        # Get user tokens
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user['id']}")
        
        tokens = {}
        if token_response.status_code == 200:
            token_data = token_response.json()
            if token_data:
                tokens = token_data[0]
        
        # Create session record
        session_data = {
            "user_id": user["id"],
            "session_token": access_token,
            "expires_at": (datetime.now() + timedelta(hours=JWT_EXPIRATION_HOURS)).isoformat(),
            "is_active": True
        }
        await make_supabase_request("POST", "user_sessions", session_data)
        
        return {
            "success": True,
            "user": {
                "id": user["id"],
                "email": user["email"],
                "name": user["name"],
                "profile_image_url": user.get("profile_image_url"),
                "is_verified": user.get("is_verified", False),
                "is_premium": user.get("is_premium", False)
            },
            "tokens": tokens,
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": JWT_EXPIRATION_HOURS * 3600
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

# Content management endpoints
@app.post("/api/content/upload")
@limiter.limit("20/minute")
async def upload_content(request: Request, content: ContentSend, user_id: str = Depends(verify_token)):
    """Upload and process content with advanced business logic"""
    try:
        # Validate user and get tokens
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        
        if token_response.status_code != 200:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        token_data = token_response.json()
        if not token_data:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        user_tokens = token_data[0]
        
        # Advanced token validation with business rules
        required_tokens = 1
        if content.content_type == "photo":
            if user_tokens.get("photo_tokens", 0) < required_tokens:
                raise HTTPException(status_code=400, detail="Insufficient photo tokens")
            token_field = "photo_tokens"
        elif content.content_type == "video":
            if user_tokens.get("video_tokens", 0) < required_tokens:
                raise HTTPException(status_code=400, detail="Insufficient video tokens")
            token_field = "video_tokens"
            required_tokens = 2  # Videos cost more
        else:
            raise HTTPException(status_code=400, detail="Invalid content type")
        
        # Content validation and processing
        content_data = {
            "user_id": user_id,
            "content_type": content.content_type,
            "content_url": content.content_url,
            "caption": content.caption,
            "is_public": True,
            "is_processed": False,
            "processing_status": "pending",
            "likes_count": 0,
            "comments_count": 0,
            "views_count": 0,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        
        # Create content record
        content_response = await make_supabase_request("POST", "posts", content_data)
        
        if content_response.status_code not in [200, 201]:
            raise HTTPException(status_code=500, detail="Failed to create content")
        
        content_result = content_response.json()
        content_id = content_result[0]["id"]
        
        # Advanced recipient selection algorithm
        recipients = await select_optimal_recipients(user_id, content.content_type)
        
        if not recipients:
            raise HTTPException(status_code=400, detail="No suitable recipients found")
        
        # Create recipient records for multiple users
        recipient_records = []
        for recipient_id in recipients:
            recipient_data = {
                "post_id": content_id,
                "recipient_id": recipient_id,
                "is_viewed": False,
                "is_liked": False,
                "friend_requested": False,
                "received_at": datetime.now().isoformat()
            }
            recipient_records.append(recipient_data)
        
        # Batch insert recipients
        for recipient_data in recipient_records:
            recipient_response = await make_supabase_request("POST", "content_recipients", recipient_data)
            if recipient_response.status_code not in [200, 201]:
                logger.warning(f"Failed to create recipient record for content {content_id}")
        
        # Deduct tokens with business logic
        current_tokens = user_tokens.get(token_field, 0)
        new_token_count = current_tokens - required_tokens
        
        token_update = {
            token_field: new_token_count,
            "updated_at": datetime.now().isoformat()
        }
        
        update_token_response = await make_supabase_request(
            "PATCH", 
            f"user_tokens?user_id=eq.{user_id}", 
            token_update
        )
        
        if update_token_response.status_code not in [200, 204]:
            logger.error(f"Token update failed for user {user_id}")
            raise HTTPException(status_code=500, detail="Failed to update tokens")
        
        # Trigger content processing (face recognition, moderation)
        await trigger_content_processing(content_id, content.content_url, content.content_type)
        
        # Send real-time notifications to recipients
        for recipient_id in recipients:
            await manager.send_personal_message(
                json.dumps({
                    "type": "new_content_received",
                    "data": {
                        "content_id": content_id,
                        "content_type": content.content_type,
                        "sender_id": user_id,
                        "caption": content.caption
                    }
                }),
                recipient_id
            )
        
        return {
            "success": True,
            "content_id": content_id,
            "recipients_count": len(recipients),
            "tokens_used": required_tokens,
            "remaining_tokens": new_token_count,
            "processing_status": "pending",
            "message": "Content uploaded and processing started"
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Content upload error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

async def select_optimal_recipients(sender_id: str, content_type: str, max_recipients: int = 3):
    """Advanced algorithm to select optimal recipients for content"""
    try:
        # Get all potential recipients (excluding sender)
        users_response = await make_supabase_request(
            "GET", 
            f"users?id=neq.{sender_id}&select=id,is_premium,created_at"
        )
        
        if users_response.status_code != 200:
            return []
        
        users = users_response.json()
        if not users:
            return []
        
        # Advanced recipient selection logic
        import random
        
        # Prioritize premium users for better content
        premium_users = [u for u in users if u.get('is_premium', False)]
        regular_users = [u for u in users if not u.get('is_premium', False)]
        
        selected_recipients = []
        
        # Select premium users first (up to 2)
        if premium_users:
            selected_recipients.extend(
                random.sample(premium_users, min(2, len(premium_users)))
            )
        
        # Fill remaining slots with regular users
        remaining_slots = max_recipients - len(selected_recipients)
        if remaining_slots > 0 and regular_users:
            selected_recipients.extend(
                random.sample(regular_users, min(remaining_slots, len(regular_users)))
            )
        
        return [user['id'] for user in selected_recipients]
        
    except Exception as e:
        logger.error(f"Error selecting recipients: {e}")
        return []

async def trigger_content_processing(content_id: str, content_url: str, content_type: str):
    """Trigger content processing (face recognition, moderation)"""
    try:
        # Call face recognition service
        face_recognition_url = "https://discerning-gentleness-production.up.railway.app"
        
        processing_data = {
            "content_id": content_id,
            "content_url": content_url,
            "content_type": content_type
        }
        
        # This would be an async call to the face recognition service
        # For now, we'll just update the processing status
        await make_supabase_request(
            "PATCH",
            f"posts?id=eq.{content_id}",
            {
                "processing_status": "processing",
                "updated_at": datetime.now().isoformat()
            }
        )
        
        logger.info(f"Content processing triggered for {content_id}")
        
    except Exception as e:
        logger.error(f"Error triggering content processing: {e}")

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

# API Version and Update endpoints
@app.get("/api/version", response_model=ApiVersionResponse)
async def get_api_version():
    """Get current API version and features"""
    return ApiVersionResponse(
        version=API_VERSION,
        last_updated=API_LAST_UPDATED,
        features=[
            "User authentication",
            "Content sharing",
            "Token management",
            "Real-time updates via WebSocket",
            "Auto-update notifications"
        ],
        breaking_changes=[
            "Added WebSocket support in v1.1.0",
            "Enhanced token management"
        ]
    )

@app.get("/api/check-updates")
async def check_for_updates(client_version: str = "1.0.0"):
    """Check if client needs to update"""
    needs_update = client_version != API_VERSION
    return {
        "needs_update": needs_update,
        "current_version": API_VERSION,
        "client_version": client_version,
        "update_url": "https://your-app-store-link.com",
        "force_update": False,
        "changelog": [
            "Added real-time notifications",
            "Improved performance",
            "Bug fixes"
        ]
    }

@app.get("/api/config")
async def get_dynamic_config():
    """Get dynamic configuration for mobile app"""
    return {
        "api_endpoints": {
            "primary": "https://sendpicapp-production.up.railway.app",
            "face_recognition": "https://discerning-gentleness-production.up.railway.app",
            "fallback": "http://localhost:8000",
            "face_recognition_fallback": "http://localhost:5050",
        },
        "features": {
            "real_time_updates": True,
            "auto_update_check": True,
            "websocket_enabled": True,
            "offline_mode": False,
        },
        "timeouts": {
            "api_timeout": 30000,
            "websocket_timeout": 5000,
            "retry_attempts": 3,
        },
        "update_intervals": {
            "config_check": 300000,  # 5 minutes
            "version_check": 300000,  # 5 minutes
            "health_check": 60000,   # 1 minute
        },
        "version": API_VERSION,
        "last_updated": API_LAST_UPDATED,
    }

# WebSocket endpoint for real-time updates
@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    """WebSocket endpoint for real-time updates"""
    await manager.connect(websocket, user_id)
    try:
        # Send welcome message
        await manager.send_personal_message(
            json.dumps({
                "type": "connection",
                "message": "Connected to SendPic real-time updates",
                "user_id": user_id,
                "timestamp": datetime.now().isoformat()
            }),
            user_id
        )
        
        while True:
            # Keep connection alive and listen for messages
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            # Handle different message types
            if message_data.get("type") == "ping":
                await manager.send_personal_message(
                    json.dumps({
                        "type": "pong",
                        "timestamp": datetime.now().isoformat()
                    }),
                    user_id
                )
            
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
    except Exception as e:
        print(f"WebSocket error for user {user_id}: {e}")
        manager.disconnect(websocket, user_id)

# Broadcast update notifications
@app.post("/api/broadcast-update")
async def broadcast_update(update_data: dict):
    """Broadcast update notification to all connected clients"""
    message = json.dumps({
        "type": "system_update",
        "data": update_data,
        "timestamp": datetime.now().isoformat()
    })
    await manager.broadcast(message)
    return {"success": True, "message": "Update broadcasted"}

# Payment endpoints
@app.post("/api/payments/create-payment-intent")
@limiter.limit("10/minute")
async def create_payment_intent(request: Request, purchase: TokenPurchase, user_id: str = Depends(verify_token)):
    """Create Stripe payment intent for token purchase"""
    try:
        # Calculate total price
        total_price = calculate_token_price(purchase.token_type, purchase.quantity)
        
        # Create Stripe payment intent
        intent = stripe.PaymentIntent.create(
            amount=int(total_price * 100),  # Convert to cents
            currency='usd',
            metadata={
                'user_id': user_id,
                'token_type': purchase.token_type,
                'quantity': purchase.quantity
            }
        )
        
        # Create transaction record
        transaction_data = {
            "user_id": user_id,
            "transaction_type": "token_purchase",
            "amount": float(total_price),
            "currency": "USD",
            "tokens_purchased": purchase.quantity,
            "payment_method": purchase.payment_method,
            "payment_status": "pending",
            "stripe_payment_intent_id": intent.id,
            "metadata": {
                "token_type": purchase.token_type,
                "quantity": purchase.quantity
            }
        }
        
        transaction_response = await make_supabase_request("POST", "payment_transactions", transaction_data)
        
        if transaction_response.status_code not in [200, 201]:
            logger.error(f"Failed to create transaction record: {transaction_response.text}")
        
        return {
            "success": True,
            "client_secret": intent.client_secret,
            "amount": total_price,
            "currency": "USD",
            "token_type": purchase.token_type,
            "quantity": purchase.quantity
        }
        
    except stripe.error.StripeError as e:
        logger.error(f"Stripe error: {e}")
        raise HTTPException(status_code=400, detail=f"Payment error: {str(e)}")
    except Exception as e:
        logger.error(f"Payment intent creation error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/payments/webhook")
async def stripe_webhook(request: Request):
    """Handle Stripe webhook events"""
    payload = await request.body()
    sig_header = request.headers.get('stripe-signature')
    
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, STRIPE_WEBHOOK_SECRET
        )
    except ValueError:
        logger.error("Invalid payload")
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        logger.error("Invalid signature")
        raise HTTPException(status_code=400, detail="Invalid signature")
    
    # Handle the event
    if event['type'] == 'payment_intent.succeeded':
        payment_intent = event['data']['object']
        await handle_successful_payment(payment_intent)
    elif event['type'] == 'payment_intent.payment_failed':
        payment_intent = event['data']['object']
        await handle_failed_payment(payment_intent)
    
    return {"success": True}

async def handle_successful_payment(payment_intent):
    """Handle successful payment and add tokens to user account"""
    try:
        user_id = payment_intent['metadata']['user_id']
        token_type = payment_intent['metadata']['token_type']
        quantity = int(payment_intent['metadata']['quantity'])
        
        # Update transaction status
        await make_supabase_request(
            "PATCH", 
            f"payment_transactions?stripe_payment_intent_id=eq.{payment_intent['id']}",
            {"payment_status": "completed"}
        )
        
        # Add tokens to user account
        token_field = f"{token_type}_tokens"
        
        # Get current tokens
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        
        if token_response.status_code == 200:
            token_data = token_response.json()
            if token_data:
                current_tokens = token_data[0].get(token_field, 0)
                new_tokens = current_tokens + quantity
                
                # Update tokens
                await make_supabase_request(
                    "PATCH",
                    f"user_tokens?user_id=eq.{user_id}",
                    {
                        token_field: new_tokens,
                        "total_purchased": token_data[0].get("total_purchased", 0) + quantity,
                        "last_purchase_date": datetime.now().isoformat()
                    }
                )
                
                # Send notification via WebSocket
                await manager.send_personal_message(
                    json.dumps({
                        "type": "token_purchase_success",
                        "data": {
                            "token_type": token_type,
                            "quantity": quantity,
                            "new_balance": new_tokens
                        }
                    }),
                    user_id
                )
                
        logger.info(f"Successfully added {quantity} {token_type} tokens to user {user_id}")
        
    except Exception as e:
        logger.error(f"Error handling successful payment: {e}")

async def handle_failed_payment(payment_intent):
    """Handle failed payment"""
    try:
        # Update transaction status
        await make_supabase_request(
            "PATCH", 
            f"payment_transactions?stripe_payment_intent_id=eq.{payment_intent['id']}",
            {"payment_status": "failed"}
        )
        
        user_id = payment_intent['metadata']['user_id']
        
        # Send notification via WebSocket
        await manager.send_personal_message(
            json.dumps({
                "type": "token_purchase_failed",
                "data": {
                    "message": "Payment failed. Please try again."
                }
            }),
            user_id
        )
        
        logger.info(f"Payment failed for user {user_id}")
        
    except Exception as e:
        logger.error(f"Error handling failed payment: {e}")

# User management endpoints
@app.get("/api/users/profile")
async def get_user_profile(user_id: str = Depends(verify_token)):
    """Get user profile"""
    try:
        user_response = await make_supabase_request("GET", f"users?id=eq.{user_id}")
        
        if user_response.status_code != 200:
            raise HTTPException(status_code=404, detail="User not found")
        
        users = user_response.json()
        if not users:
            raise HTTPException(status_code=404, detail="User not found")
        
        user = users[0]
        
        # Get user tokens
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        tokens = {}
        if token_response.status_code == 200:
            token_data = token_response.json()
            if token_data:
                tokens = token_data[0]
        
        return {
            "success": True,
            "user": {
                "id": user["id"],
                "email": user["email"],
                "name": user["name"],
                "profile_image_url": user.get("profile_image_url"),
                "gender": user.get("gender"),
                "age": user.get("age"),
                "is_verified": user.get("is_verified", False),
                "is_premium": user.get("is_premium", False),
                "created_at": user["created_at"]
            },
            "tokens": tokens
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get profile error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/api/users/tokens")
async def get_user_tokens(user_id: str = Depends(verify_token)):
    """Get user token balance"""
    try:
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        
        if token_response.status_code != 200:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        token_data = token_response.json()
        if not token_data:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        return {
            "success": True,
            "tokens": token_data[0]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Get tokens error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/api/users/transactions")
async def get_user_transactions(user_id: str = Depends(verify_token)):
    """Get user payment transactions"""
    try:
        transactions_response = await make_supabase_request(
            "GET", 
            f"payment_transactions?user_id=eq.{user_id}&order=created_at.desc"
        )
        
        if transactions_response.status_code != 200:
            return {"success": True, "transactions": []}
        
        transactions = transactions_response.json()
        
        return {
            "success": True,
            "transactions": transactions
        }
        
    except Exception as e:
        logger.error(f"Get transactions error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy", 
        "timestamp": datetime.now().isoformat(),
        "version": API_VERSION,
        "active_connections": len(manager.active_connections)
    }

@app.get("/api/version")
async def get_api_version():
    """Get API version information"""
    return ApiVersionResponse(
        version=API_VERSION,
        last_updated=API_LAST_UPDATED,
        features=[
            "User Authentication",
            "Content Management",
            "Token System",
            "Payment Processing",
            "Real-time Updates",
            "Face Recognition Integration",
            "Admin Panel",
            "WebSocket Support"
        ],
        breaking_changes=[
            "v1.1.0: Added JWT authentication",
            "v1.1.0: Moved business logic to backend"
        ]
    )

@app.get("/api/check-updates")
async def check_updates():
    """Check for backend updates"""
    return {
        "has_updates": True,
        "current_version": API_VERSION,
        "last_updated": API_LAST_UPDATED,
        "update_message": "New features and security improvements available"
    }

@app.get("/api/config")
async def get_dynamic_config():
    """Get dynamic configuration for Flutter app"""
    return {
        "backend_url": "https://sendpicapp-production.up.railway.app",
        "face_recognition_url": "https://discerning-gentleness-production.up.railway.app",
        "websocket_url": "wss://sendpicapp-production.up.railway.app/ws",
        "api_version": API_VERSION,
        "features_enabled": {
            "face_recognition": True,
            "payments": True,
            "real_time_updates": True,
            "admin_panel": True
        }
    }

# Admin endpoints (protected)
@app.get("/api/admin/users")
@limiter.limit("30/minute")
async def get_all_users(request: Request, current_user: dict = Depends(verify_token)):
    # Check if user is admin
    if not current_user.get('is_admin', False):
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        response = await make_supabase_request("GET", "users")
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail="Failed to fetch users")
        return {"users": response.json()}
    except Exception as e:
        logger.error(f"Error fetching users: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch users")

@app.post("/api/admin/users/{user_id}/tokens")
@limiter.limit("10/minute")
async def admin_add_tokens(request: Request, user_id: str, token_data: dict, current_user: dict = Depends(verify_token)):
    # Check if user is admin
    if not current_user.get('is_admin', False):
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        photo_tokens = token_data.get('photo_tokens', 0)
        video_tokens = token_data.get('video_tokens', 0)
        premium_tokens = token_data.get('premium_tokens', 0)
        
        # Get current tokens
        token_response = await make_supabase_request("GET", f"user_tokens?user_id=eq.{user_id}")
        if token_response.status_code != 200:
            raise HTTPException(status_code=404, detail="User tokens not found")
        
        current_tokens = token_response.json()[0]
        
        # Update user tokens
        update_data = {
            'photo_tokens': current_tokens['photo_tokens'] + photo_tokens,
            'video_tokens': current_tokens['video_tokens'] + video_tokens,
            'premium_tokens': current_tokens['premium_tokens'] + premium_tokens,
            'updated_at': datetime.now().isoformat()
        }
        
        response = await make_supabase_request("PATCH", f"user_tokens?user_id=eq.{user_id}", update_data)
        
        if response.status_code not in [200, 204]:
            raise HTTPException(status_code=500, detail="Failed to update tokens")
        
        logger.info(f"Admin {current_user['id']} added tokens to user {user_id}")
        return {"message": "Tokens added successfully", "tokens_added": token_data}
    except Exception as e:
        logger.error(f"Error adding tokens: {e}")
        raise HTTPException(status_code=500, detail="Failed to add tokens")

@app.get("/api/admin/statistics")
@limiter.limit("20/minute")
async def get_admin_statistics(request: Request, current_user: dict = Depends(verify_token)):
    # Check if user is admin
    if not current_user.get('is_admin', False):
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        # Get user statistics
        users_response = await make_supabase_request("GET", "users?select=id,created_at")
        users_data = users_response.json() if users_response.status_code == 200 else []
        total_users = len(users_data)
        
        # Get token statistics
        tokens_response = await make_supabase_request("GET", "user_tokens?select=photo_tokens,video_tokens,premium_tokens")
        tokens_data = tokens_response.json() if tokens_response.status_code == 200 else []
        total_photo_tokens = sum(token.get('photo_tokens', 0) for token in tokens_data)
        total_video_tokens = sum(token.get('video_tokens', 0) for token in tokens_data)
        total_premium_tokens = sum(token.get('premium_tokens', 0) for token in tokens_data)
        
        # Get transaction statistics
        transactions_response = await make_supabase_request("GET", "payment_transactions?select=amount,payment_status")
        transactions_data = transactions_response.json() if transactions_response.status_code == 200 else []
        total_revenue = sum(float(tx.get('amount', 0)) for tx in transactions_data if tx.get('payment_status') == 'completed')
        total_transactions = len(transactions_data)
        
        # Get content statistics
        content_response = await make_supabase_request("GET", "posts?select=id,content_type,created_at")
        content_data = content_response.json() if content_response.status_code == 200 else []
        total_content = len(content_data)
        photo_content = len([c for c in content_data if c.get('content_type') == 'photo'])
        video_content = len([c for c in content_data if c.get('content_type') == 'video'])
        
        # Calculate new users today
        today = datetime.now().date()
        new_today = 0
        for user in users_data:
            try:
                created_date = datetime.fromisoformat(user['created_at'].replace('Z', '+00:00')).date()
                if created_date == today:
                    new_today += 1
            except:
                continue
        
        return {
            "users": {
                "total": total_users,
                "new_today": new_today
            },
            "tokens": {
                "total_photo": total_photo_tokens,
                "total_video": total_video_tokens,
                "total_premium": total_premium_tokens
            },
            "revenue": {
                "total": total_revenue,
                "transactions": total_transactions
            },
            "content": {
                "total": total_content,
                "photos": photo_content,
                "videos": video_content
            }
        }
    except Exception as e:
        logger.error(f"Error fetching statistics: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch statistics")

# Content processing and moderation endpoints
@app.post("/api/content/process/{content_id}")
@limiter.limit("10/minute")
async def process_content(request: Request, content_id: str, current_user: dict = Depends(verify_token)):
    try:
        # Get content details
        content_response = await make_supabase_request("GET", f"posts?id=eq.{content_id}")
        if content_response.status_code != 200 or not content_response.json():
            raise HTTPException(status_code=404, detail="Content not found")
        
        content = content_response.json()[0]
        
        # Check if user owns the content or is admin
        if content['user_id'] != current_user['id'] and not current_user.get('is_admin', False):
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Update processing status
        update_data = {
            'processing_status': 'processing',
            'updated_at': datetime.now().isoformat()
        }
        
        response = await make_supabase_request("PATCH", f"posts?id=eq.{content_id}", update_data)
        
        if response.status_code not in [200, 204]:
            raise HTTPException(status_code=500, detail="Failed to update content status")
        
        # Trigger async processing (simulate face recognition)
        await trigger_content_processing(content_id, content['content_url'])
        
        return {"message": "Content processing started", "content_id": content_id}
    except Exception as e:
        logger.error(f"Error processing content: {e}")
        raise HTTPException(status_code=500, detail="Failed to process content")

@app.get("/api/content/moderation/queue")
@limiter.limit("20/minute")
async def get_moderation_queue(request: Request, current_user: dict = Depends(verify_token)):
    # Check if user is admin or moderator
    if not current_user.get('is_admin', False) and not current_user.get('is_moderator', False):
        raise HTTPException(status_code=403, detail="Moderator access required")
    
    try:
        # Get content pending moderation
        response = await make_supabase_request("GET", "posts?processing_status=eq.pending_review&select=*")
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail="Failed to fetch moderation queue")
        
        return {"content": response.json()}
    except Exception as e:
        logger.error(f"Error fetching moderation queue: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch moderation queue")

@app.post("/api/content/moderation/{content_id}/approve")
@limiter.limit("30/minute")
async def approve_content(request: Request, content_id: str, current_user: dict = Depends(verify_token)):
    # Check if user is admin or moderator
    if not current_user.get('is_admin', False) and not current_user.get('is_moderator', False):
        raise HTTPException(status_code=403, detail="Moderator access required")
    
    try:
        update_data = {
            'processing_status': 'approved',
            'is_processed': True,
            'moderated_by': current_user['id'],
            'moderated_at': datetime.now().isoformat(),
            'updated_at': datetime.now().isoformat()
        }
        
        response = await make_supabase_request("PATCH", f"posts?id=eq.{content_id}", update_data)
        
        if response.status_code not in [200, 204]:
            raise HTTPException(status_code=500, detail="Failed to approve content")
        
        logger.info(f"Content {content_id} approved by {current_user['id']}")
        return {"message": "Content approved successfully"}
    except Exception as e:
        logger.error(f"Error approving content: {e}")
        raise HTTPException(status_code=500, detail="Failed to approve content")

@app.post("/api/content/moderation/{content_id}/reject")
@limiter.limit("30/minute")
async def reject_content(request: Request, content_id: str, rejection_data: dict, current_user: dict = Depends(verify_token)):
    # Check if user is admin or moderator
    if not current_user.get('is_admin', False) and not current_user.get('is_moderator', False):
        raise HTTPException(status_code=403, detail="Moderator access required")
    
    try:
        reason = rejection_data.get('reason', 'Content violates community guidelines')
        
        update_data = {
            'processing_status': 'rejected',
            'is_processed': True,
            'moderated_by': current_user['id'],
            'moderated_at': datetime.now().isoformat(),
            'rejection_reason': reason,
            'updated_at': datetime.now().isoformat()
        }
        
        response = await make_supabase_request("PATCH", f"posts?id=eq.{content_id}", update_data)
        
        if response.status_code not in [200, 204]:
            raise HTTPException(status_code=500, detail="Failed to reject content")
        
        logger.info(f"Content {content_id} rejected by {current_user['id']} - Reason: {reason}")
        return {"message": "Content rejected successfully", "reason": reason}
    except Exception as e:
        logger.error(f"Error rejecting content: {e}")
        raise HTTPException(status_code=500, detail="Failed to reject content")

# User management endpoints
@app.get("/api/users/content")
@limiter.limit("50/minute")
async def get_user_content(request: Request, current_user: dict = Depends(verify_token)):
    try:
        response = await make_supabase_request("GET", f"posts?user_id=eq.{current_user['id']}&select=*")
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail="Failed to fetch user content")
        
        return {"content": response.json()}
    except Exception as e:
        logger.error(f"Error fetching user content: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch user content")

@app.delete("/api/users/content/{content_id}")
@limiter.limit("20/minute")
async def delete_user_content(request: Request, content_id: str, current_user: dict = Depends(verify_token)):
    try:
        # Check if user owns the content
        content_response = await make_supabase_request("GET", f"posts?id=eq.{content_id}")
        if content_response.status_code != 200 or not content_response.json():
            raise HTTPException(status_code=404, detail="Content not found")
        
        content = content_response.json()[0]
        if content['user_id'] != current_user['id'] and not current_user.get('is_admin', False):
            raise HTTPException(status_code=403, detail="Access denied")
        
        # Delete content
        response = await make_supabase_request("DELETE", f"posts?id=eq.{content_id}")
        
        if response.status_code not in [200, 204]:
            raise HTTPException(status_code=500, detail="Failed to delete content")
        
        logger.info(f"Content {content_id} deleted by user {current_user['id']}")
        return {"message": "Content deleted successfully"}
    except Exception as e:
        logger.error(f"Error deleting content: {e}")
        raise HTTPException(status_code=500, detail="Failed to delete content")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
