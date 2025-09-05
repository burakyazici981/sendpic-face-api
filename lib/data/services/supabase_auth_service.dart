import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';

class SupabaseAuthService {
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  SupabaseClient get _client => SupabaseConfig.client;
  User? get currentUser => _client.auth.currentUser;
  UserModel? _currentUserModel;
  UserModel? get currentUserModel => _currentUserModel;

  // Initialize service
  Future<void> initialize() async {
    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final User? user = data.session?.user;
      
      if (event == AuthChangeEvent.signedIn && user != null) {
        _loadUserProfile(user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUserModel = null;
      }
    });

    // Load current user if already signed in
    if (currentUser != null) {
      await _loadUserProfile(currentUser!.id);
    }
  }

  // Load user profile from database
  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      
      _currentUserModel = UserModel.fromSupabaseJson(response);
    } catch (e) {
      print('Error loading user profile: $e');
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
      final AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'profile_image_url': profileImageUrl,
          'gender': gender,
          'age': age,
          'birth_date': birthDate?.toIso8601String().split('T')[0],
        },
      );

      if (response.user != null) {
        // Update user profile in our custom table
        await _client.from('users').insert({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'profile_image_url': profileImageUrl,
          'bio': null,
          'gender': gender,
          'age': age,
          'birth_date': birthDate?.toIso8601String().split('T')[0],
          'is_verified': true, // Auto-verify for now
        });

        // Give new users 100 tokens
        await _giveWelcomeTokens(response.user!.id);

        await _loadUserProfile(response.user!.id);
        return _currentUserModel;
      }
      
      return null;
    } catch (e) {
      print('Registration error: $e');
      throw _handleAuthError(e);
    }
  }

  // Login user
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        return _currentUserModel;
      }
      
      return null;
    } catch (e) {
      print('Login error: $e');
      throw _handleAuthError(e);
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
      _currentUserModel = null;
    } catch (e) {
      print('Logout error: $e');
      throw _handleAuthError(e);
    }
  }

  // Update user profile
  Future<UserModel?> updateProfile({
    String? name,
    String? profileImageUrl,
    String? bio,
    String? gender,
    int? age,
  }) async {
    try {
      if (currentUser == null) return null;

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;
      if (bio != null) updates['bio'] = bio;
      if (gender != null) updates['gender'] = gender;
      if (age != null) updates['age'] = age;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('users')
          .update(updates)
          .eq('id', currentUser!.id);

      await _loadUserProfile(currentUser!.id);
      return _currentUserModel;
    } catch (e) {
      print('Update profile error: $e');
      throw _handleAuthError(e);
    }
  }

  // Change password
  Future<bool> changePassword({
    required String newPassword,
  }) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      print('Change password error: $e');
      throw _handleAuthError(e);
    }
  }

  // Get user tokens
  Future<Map<String, int>> getUserTokens() async {
    try {
      if (currentUser == null) return {};

      final response = await _client
          .from('user_tokens')
          .select()
          .eq('user_id', currentUser!.id)
          .single();

      return {
        'photo_tokens': response['photo_tokens'] ?? 0,
        'video_tokens': response['video_tokens'] ?? 0,
        'premium_tokens': response['premium_tokens'] ?? 0,
      };
    } catch (e) {
      print('Error getting user tokens: $e');
      return {};
    }
  }

  // Update user tokens
  Future<bool> updateUserTokens(Map<String, int> tokenUpdates) async {
    try {
      if (currentUser == null) return false;

      // Get current tokens
      final currentTokens = await getUserTokens();
      
      // Apply updates
      final newTokens = <String, int>{};
      tokenUpdates.forEach((key, value) {
        newTokens[key] = (currentTokens[key] ?? 0) + value;
        if (newTokens[key]! < 0) newTokens[key] = 0;
      });

      // Update in database
      await _client
          .from('user_tokens')
          .update({
            ...newTokens,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', currentUser!.id);

      // Record transaction
      for (final entry in tokenUpdates.entries) {
        await _client.from('token_transactions').insert({
          'user_id': currentUser!.id,
          'transaction_type': entry.value > 0 ? 'earned' : 'spent',
          'token_type': entry.key,
          'amount': entry.value.abs(),
          'description': entry.value > 0 ? 'Tokens earned' : 'Tokens spent',
        });
      }

      return true;
    } catch (e) {
      print('Error updating user tokens: $e');
      return false;
    }
  }

  // Upload file to Supabase Storage
  Future<String?> uploadFile({
    required File file,
    required String bucket,
    required String path,
  }) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path}';
      
      await _client.storage
          .from(bucket)
          .upload(fileName, file);

      final String publicUrl = _client.storage
          .from(bucket)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Give welcome tokens to new users
  Future<void> _giveWelcomeTokens(String userId) async {
    try {
      // Create user_tokens record with 100 initial tokens
      await _client.from('user_tokens').insert({
        'user_id': userId,
        'photo_tokens': 100,
        'video_tokens': 0,
        'premium_tokens': 0,
      });

      // Record the welcome bonus transaction
      await _client.from('token_transactions').insert({
        'user_id': userId,
        'transaction_type': 'earned',
        'token_type': 'photo_tokens',
        'amount': 100,
        'description': 'Welcome bonus - 100 free tokens!',
      });

      print('Welcome tokens granted to user: $userId');
    } catch (e) {
      print('Error giving welcome tokens: $e');
      // Don't throw error, just log it
    }
  }

  // Handle authentication errors
  Exception _handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return Exception('Invalid email or password');
        case 'User already registered':
          return Exception('This email is already in use');
        case 'Password should be at least 6 characters':
          return Exception('Password must be at least 6 characters');
        default:
          return Exception(error.message);
      }
    }
    return Exception('An error occurred: $error');
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Get current session
  Session? get currentSession => _client.auth.currentSession;
}