import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendApiService {
  static final BackendApiService _instance = BackendApiService._internal();
  factory BackendApiService() => _instance;
  BackendApiService._internal();

  // Backend API base URL
  static const String _baseUrl = 'https://sendpic-backend-api.railway.app';
  
  String? _accessToken;
  String? _userId;

  // Initialize service
  Future<void> initialize() async {
    await _loadStoredCredentials();
  }

  // Load stored credentials
  Future<void> _loadStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _userId = prefs.getString('user_id');
    } catch (e) {
      print('Error loading stored credentials: $e');
    }
  }

  // Save credentials
  Future<void> _saveCredentials(String accessToken, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      await prefs.setString('user_id', userId);
      _accessToken = accessToken;
      _userId = userId;
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  // Clear credentials
  Future<void> clearCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('user_id');
      _accessToken = null;
      _userId = null;
    } catch (e) {
      print('Error clearing credentials: $e');
    }
  }

  // Get headers for API requests
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    
    if (_userId != null) {
      headers['X-User-ID'] = _userId!;
    }
    
    return headers;
  }

  // Register user
  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String name,
    String? profileImageUrl,
    String? gender,
    int? age,
    DateTime? birthDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
          'profile_image_url': profileImageUrl,
          'gender': gender,
          'age': age,
          'birth_date': birthDate?.toIso8601String().split('T')[0],
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  // Login user
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        // Save credentials
        if (result['access_token'] != null && result['user'] != null) {
          await _saveCredentials(
            result['access_token'],
            result['user']['id'],
          );
        }
        
        return result;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  // Send content
  Future<Map<String, dynamic>?> sendContent({
    required String contentType,
    required String contentUrl,
    String? caption,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/content/send'),
        headers: _getHeaders(),
        body: jsonEncode({
          'content_type': contentType,
          'content_url': contentUrl,
          'caption': caption,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Content send failed');
      }
    } catch (e) {
      print('Send content error: $e');
      rethrow;
    }
  }

  // Get received content
  Future<Map<String, dynamic>?> getReceivedContent() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/content/received'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to get received content');
      }
    } catch (e) {
      print('Get received content error: $e');
      rethrow;
    }
  }

  // Get user tokens
  Future<Map<String, dynamic>?> getUserTokens() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/tokens'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Failed to get user tokens');
      }
    } catch (e) {
      print('Get user tokens error: $e');
      rethrow;
    }
  }

  // Check if user is logged in
  bool get isLoggedIn => _accessToken != null && _userId != null;

  // Get current user ID
  String? get currentUserId => _userId;
}
