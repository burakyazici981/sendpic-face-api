import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/content_recipient_model.dart';
import '../models/friendship_model.dart';
import '../models/message_model.dart';
import '../../core/constants/app_constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Uuid _uuid = const Uuid();
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Initialize service
  Future<void> initialize() async {
    // Clear any corrupted data first
    await _clearCorruptedData();
    await _loadUserSession();
  }

  // Clear corrupted SharedPreferences data
  Future<void> _clearCorruptedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if users data exists and is valid
      final usersJson = prefs.getString('sendpic_users');
      if (usersJson != null) {
        try {
          final usersList = jsonDecode(usersJson) as List;
          // Check if any user has boolean is_verified instead of integer
          bool hasCorruptedData = false;
          for (final user in usersList) {
            if (user is Map<String, dynamic> && user['is_verified'] is bool) {
              hasCorruptedData = true;
              break;
            }
          }
          if (hasCorruptedData) {
            print('Clearing corrupted user data...');
            await prefs.remove('sendpic_users');
            await prefs.remove(AppConstants.userSessionKey);
          }
        } catch (e) {
          print('Error checking user data, clearing: $e');
          await prefs.remove('sendpic_users');
          await prefs.remove(AppConstants.userSessionKey);
        }
      }
    } catch (e) {
      print('Error in _clearCorruptedData: $e');
    }
  }

  // Load user session from SharedPreferences
  Future<void> _loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userSessionJson = prefs.getString(AppConstants.userSessionKey);
      
      if (userSessionJson != null) {
        final userMap = jsonDecode(userSessionJson) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(userMap);
      }
    } catch (e) {
      print('Error loading user session: $e');
      _currentUser = null;
    }
  }

  // Save user session to SharedPreferences
  Future<void> _saveUserSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userSessionKey, jsonEncode(user.toJson()));
      _currentUser = user;
    } catch (e) {
      print('Error saving user session: $e');
    }
  }

  // Clear user session
  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.userSessionKey);
      _currentUser = null;
    } catch (e) {
      print('Error clearing user session: $e');
    }
  }

  // Get all users from SharedPreferences
  Future<List<UserModel>> _getUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString('sendpic_users');
      
      if (usersJson == null) {
        return [];
      }
      
      final usersList = jsonDecode(usersJson) as List;
      return usersList.map((json) => UserModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // Save users to SharedPreferences
  Future<void> _saveUsers(List<UserModel> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sendpic_users', jsonEncode(users.map((user) => user.toJson()).toList()));
    } catch (e) {
      print('Error saving users: $e');
    }
  }

  // Register new user
  Future<UserModel?> register({
    required String email,
    required String password,
    required String name,
    String? profileImageUrl,
    String? gender,
    int? age,
    DateTime? birthDate,
  }) async {
    try {
      // Check if user already exists
      final existingUsers = await _getUsers();
      final existingUser = existingUsers.where((u) => u.email.toLowerCase() == email.toLowerCase()).firstOrNull;
      
      if (existingUser != null) {
        throw Exception('Bu e-posta adresi zaten kullanımda');
      }

      // Hash password
      final hashedPassword = _hashPassword(password);

      // Create new user
      final newUser = UserModel(
        id: _uuid.v4(),
        email: email.toLowerCase(),
        name: name,
        passwordHash: hashedPassword,
        profileImageUrl: profileImageUrl,
        gender: gender,
        age: age,
        birthDate: birthDate,
        isVerified: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to users list
      existingUsers.add(newUser);
      await _saveUsers(existingUsers);

      // Save session
      await _saveUserSession(newUser);

      // Initialize user tokens
      await _initializeUserTokens(newUser.id);

      return newUser;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  // Login user
  Future<UserModel?> login({required String email, required String password}) async {
    try {
      final users = await _getUsers();
      final user = users.where((u) => u.email.toLowerCase() == email.toLowerCase()).firstOrNull;

      if (user == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      // Verify password
      if (!_verifyPassword(password, user.passwordHash ?? '')) {
        throw Exception('Şifre yanlış');
      }

      // Update last login
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      
      // Update user in list
      final userIndex = users.indexWhere((u) => u.id == user.id);
      if (userIndex != -1) {
        users[userIndex] = updatedUser;
        await _saveUsers(users);
      }

      // Save session
      await _saveUserSession(updatedUser);

      return updatedUser;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  // Logout user
  Future<void> logout() async {
    await _clearUserSession();
  }

  // Update user profile
  Future<UserModel?> updateProfile({
    String? name,
    String? profileImageUrl,
    bool? isVerified,
  }) async {
    try {
      if (_currentUser == null) return null;

      final updatedUser = _currentUser!.copyWith(
        name: name ?? _currentUser!.name,
        profileImageUrl: profileImageUrl ?? _currentUser!.profileImageUrl,
        isVerified: isVerified ?? _currentUser!.isVerified,
        updatedAt: DateTime.now(),
      );

      // Update in users list
      final users = await _getUsers();
      final userIndex = users.indexWhere((u) => u.id == _currentUser!.id);
      if (userIndex != -1) {
        users[userIndex] = updatedUser;
        await _saveUsers(users);
      }

      // Update session
      await _saveUserSession(updatedUser);

      return updatedUser;
    } catch (e) {
      print('Update profile error: $e');
      return null;
    }
  }

  // Change password
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      if (_currentUser == null) return false;

      // Verify current password
      if (!_verifyPassword(currentPassword, _currentUser!.passwordHash ?? '')) {
        throw Exception('Mevcut şifre yanlış');
      }

      // Hash new password
      final hashedNewPassword = _hashPassword(newPassword);

      // Update user
      final updatedUser = _currentUser!.copyWith(
        passwordHash: hashedNewPassword,
        updatedAt: DateTime.now(),
      );

      // Update in users list
      final users = await _getUsers();
      final userIndex = users.indexWhere((u) => u.id == _currentUser!.id);
      if (userIndex != -1) {
        users[userIndex] = updatedUser;
        await _saveUsers(users);
      }

      // Update session
      await _saveUserSession(updatedUser);

      return true;
    } catch (e) {
      print('Change password error: $e');
      return false;
    }
  }

  // Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Verify password
  bool _verifyPassword(String password, String hashedPassword) {
    return _hashPassword(password) == hashedPassword;
  }

  // Initialize user tokens
  Future<void> _initializeUserTokens(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokensKey = 'user_tokens_$userId';
      
      final existingTokens = prefs.getString(tokensKey);
      if (existingTokens == null) {
        // Initialize with default tokens
        final initialTokens = {
          'photo_tokens': 50,
          'video_tokens': 20,
          'premium_tokens': 0,
        };
        
        await prefs.setString(tokensKey, jsonEncode(initialTokens));
      }
    } catch (e) {
      print('Error initializing user tokens: $e');
    }
  }

  // Get user tokens
  Future<Map<String, int>> getUserTokens() async {
    try {
      if (_currentUser == null) return {};
      
      final prefs = await SharedPreferences.getInstance();
      final tokensKey = 'user_tokens_${_currentUser!.id}';
      final tokensJson = prefs.getString(tokensKey);
      
      if (tokensJson != null) {
        final tokens = jsonDecode(tokensJson) as Map<String, dynamic>;
        return tokens.map((key, value) => MapEntry(key, value as int));
      }
      
      return {};
    } catch (e) {
      print('Error getting user tokens: $e');
      return {};
    }
  }

  // Update user tokens
  Future<bool> updateUserTokens(Map<String, int> tokenUpdates) async {
    try {
      if (_currentUser == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      final tokensKey = 'user_tokens_${_currentUser!.id}';
      final tokensJson = prefs.getString(tokensKey);
      
      Map<String, int> currentTokens = {};
      if (tokensJson != null) {
        final tokens = jsonDecode(tokensJson) as Map<String, dynamic>;
        currentTokens = tokens.map((key, value) => MapEntry(key, value as int));
      }

      // Apply updates
      tokenUpdates.forEach((key, value) {
        currentTokens[key] = (currentTokens[key] ?? 0) + value;
        if (currentTokens[key]! < 0) currentTokens[key] = 0;
      });

      await prefs.setString(tokensKey, jsonEncode(currentTokens));
      return true;
    } catch (e) {
      print('Error updating user tokens: $e');
      return false;
    }
  }

  // Content management methods would go here...
  // For brevity, I'll add the essential ones

  // Get user content
  Future<List<ContentRecipientModel>> getUserContent() async {
    try {
      if (_currentUser == null) return [];
      
      final prefs = await SharedPreferences.getInstance();
      final contentKey = 'user_content_${_currentUser!.id}';
      final contentJson = prefs.getString(contentKey);
      
      if (contentJson != null) {
        final contentList = jsonDecode(contentJson) as List;
        return contentList.map((json) => ContentRecipientModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting user content: $e');
      return [];
    }
  }

  // Save content
  Future<bool> saveContent(ContentRecipientModel content) async {
    try {
      if (_currentUser == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      final contentKey = 'user_content_${_currentUser!.id}';
      final existingContent = await getUserContent();
      
      existingContent.add(content);
      
      await prefs.setString(contentKey, jsonEncode(existingContent.map((c) => c.toJson()).toList()));
      return true;
    } catch (e) {
      print('Error saving content: $e');
      return false;
    }
  }

  // Delete content
  Future<bool> deleteContent(String contentId) async {
    try {
      if (_currentUser == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      final contentKey = 'user_content_${_currentUser!.id}';
      final contentList = await getUserContent();
      
      contentList.removeWhere((content) => content.id == contentId);
      
      await prefs.setString(contentKey, jsonEncode(contentList.map((c) => c.toJson()).toList()));
      return true;
    } catch (e) {
      print('Error deleting content: $e');
      return false;
    }
  }

  // Save last login credentials
  Future<void> saveLastLoginCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_login_email', email);
      await prefs.setString('last_login_password', password);
    } catch (e) {
      print('Error saving last login credentials: $e');
    }
  }

  // Load last login credentials
  Future<Map<String, String>?> loadLastLoginCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('last_login_email');
      final password = prefs.getString('last_login_password');
      
      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
      return null;
    } catch (e) {
      print('Error loading last login credentials: $e');
      return null;
    }
  }

  // Clear last login credentials
  Future<void> clearLastLoginCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_login_email');
      await prefs.remove('last_login_password');
    } catch (e) {
      print('Error clearing last login credentials: $e');
    }
  }
}
