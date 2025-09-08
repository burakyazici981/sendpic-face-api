/// API Configuration for SendPic App
/// Now supports dynamic configuration and automatic backend switching

import '../services/dynamic_config_service.dart';

class ApiConfig {
  // Environment flag - set to false for production
  static const bool isDevelopment = false; // Changed to production
  
  // Development URLs (local servers)
  static const String _devBackendApiUrl = 'http://localhost:8000';
  static const String _devFaceRecognitionUrl = 'http://localhost:5050';
  
  // Production URLs (Railway deployed services)
  static const String _prodBackendApiUrl = 'https://sendpicapp-production.up.railway.app';
  static const String _prodFaceRecognitionUrl = 'https://discerning-gentleness-production.up.railway.app';
  
  // Dynamic configuration service
  static final DynamicConfigService _configService = DynamicConfigService();
  
  // Current URLs - now dynamic
  static String get backendApiUrl {
    if (isDevelopment) {
      return _devBackendApiUrl;
    }
    return _configService.getCurrentApiUrl();
  }
  
  static String get faceRecognitionUrl {
    if (isDevelopment) {
      return _devFaceRecognitionUrl;
    }
    return _configService.getFaceRecognitionUrl();
  }
  
  // Base URL for compatibility
  static String get baseUrl => backendApiUrl;
  
  // Supabase configuration (same for all environments)
  static const String supabaseUrl = 'https://tdxfwcgqesvgrdqidxik.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkeGZ3Y2dxZXN2Z3JkcWlkeGlrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNTgwOTQsImV4cCI6MjA3MjYzNDA5NH0.b7BQlYkNRb946mH6_-Jj9fAYNkMi6IfWt7QJ-Eal4FQ';
  
  // API Endpoints
  static String get authRegisterUrl => '$backendApiUrl/auth/register';
  static String get authLoginUrl => '$backendApiUrl/auth/login';
  static String get contentSendUrl => '$backendApiUrl/content/send';
  static String get contentReceivedUrl => '$backendApiUrl/content/received';
  static String get userTokensUrl => '$backendApiUrl/user/tokens';
  static String get healthCheckUrl => '$backendApiUrl/health';
  
  // Face Recognition Endpoints
  static String get faceDetectionUrl => '$faceRecognitionUrl/api/v1/recognize';
  static String get addFaceUrl => '$faceRecognitionUrl/api/v1/add-face';
  static String get faceHealthUrl => '$faceRecognitionUrl/health';
  
  // Request timeouts (in seconds)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 60;
  
  // File upload limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedVideoTypes = ['mp4', 'mov', 'avi'];
  
  // App configuration
  static const String appName = 'SendPic';
  static const String appVersion = '1.0.0';
  static const String supportEmail = 'support@sendpic.app';
  
  /// Get current environment info
  static Map<String, dynamic> getEnvironmentInfo() {
    return {
      'environment': isDevelopment ? 'development' : 'production',
      'backendApiUrl': backendApiUrl,
      'faceRecognitionUrl': faceRecognitionUrl,
      'supabaseUrl': supabaseUrl,
      'appVersion': appVersion,
    };
  }
  
  /// Validate if URLs are properly configured
  static bool validateConfiguration() {
    if (!isDevelopment) {
      // In production, make sure URLs are not localhost
      if (backendApiUrl.contains('localhost') || 
          faceRecognitionUrl.contains('localhost')) {
        return false;
      }
    }
    return true;
  }
}

/// HTTP Headers for API requests
class ApiHeaders {
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': '${ApiConfig.appName}/${ApiConfig.appVersion}',
  };
  
  static Map<String, String> getAuthHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
  
  static Map<String, String> getUserHeaders(String userId) => {
    ...defaultHeaders,
    'X-User-ID': userId,
  };
  
  static Map<String, String> getMultipartHeaders() => {
    'Accept': 'application/json',
    'User-Agent': '${ApiConfig.appName}/${ApiConfig.appVersion}',
  };
}

/// API Response status codes
class ApiStatusCodes {
  static const int success = 200;
  static const int created = 201;
  static const int badRequest = 400;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int tooManyRequests = 429;
  static const int internalServerError = 500;
  static const int serviceUnavailable = 503;
}