import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/backend_api_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final BackendApiService _backendApi = BackendApiService();
  
  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  
  // Use unified auth service for all platforms

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    initialize();
  }

  Future<void> initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.initialize();
      await _backendApi.initialize();
      
      // Check if user is logged in via backend API
      if (_backendApi.isLoggedIn) {
        _status = AuthStatus.authenticated;
        // Load user data from backend
        await _loadUserFromBackend();
      } else {
        _currentUser = _authService.currentUser;
        _status = _currentUser != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Session yüklenemedi';
    }
    
    notifyListeners();
  }

  // Load user data from backend
  Future<void> _loadUserFromBackend() async {
    try {
      // This will be implemented when we have the user profile endpoint
      // For now, we'll use the local auth service as fallback
      _currentUser = _authService.currentUser;
    } catch (e) {
      print('Error loading user from backend: $e');
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? profileImageUrl,
    String? gender,
    int? age,
    DateTime? birthDate,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Use backend API for registration
      final result = await _backendApi.register(
        email: email,
        password: password,
        name: name,
        profileImageUrl: profileImageUrl,
        gender: gender,
        age: age,
        birthDate: birthDate,
      );

      if (result != null && result['success'] == true) {
        // Registration successful via backend
        final userData = result['user'];
        _currentUser = UserModel(
          id: userData['id'],
          email: userData['email'],
          name: userData['username'] ?? userData['name'],
          profileImageUrl: userData['profile_image_url'],
          isVerified: userData['is_verified'] ?? false,
          createdAt: DateTime.parse(userData['created_at'] ?? DateTime.now().toIso8601String()),
          updatedAt: DateTime.parse(userData['updated_at'] ?? DateTime.now().toIso8601String()),
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      
      _status = AuthStatus.error;
      _errorMessage = result?['message'] ?? 'Hesap oluşturulamadı';
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Use backend API for login
      final result = await _backendApi.login(
        email: email,
        password: password,
      );

      if (result != null && result['success'] == true) {
        // Login successful via backend
        final userData = result['user'];
        _currentUser = UserModel(
          id: userData['id'],
          email: userData['email'],
          name: userData['username'] ?? userData['name'],
          profileImageUrl: userData['profile_image_url'],
          isVerified: userData['is_verified'] ?? false,
          createdAt: DateTime.parse(userData['created_at'] ?? DateTime.now().toIso8601String()),
          updatedAt: DateTime.parse(userData['updated_at'] ?? DateTime.now().toIso8601String()),
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      
      _status = AuthStatus.error;
      _errorMessage = result?['message'] ?? 'Giriş yapılamadı';
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getErrorMessage(e);
    }
    
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    String? profileImageUrl,
  }) async {
    try {
      final updatedUser = await _authService.updateProfile(
        name: name,
        profileImageUrl: profileImageUrl,
      );
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  // Get user tokens
  Future<Map<String, int>> getUserTokens() async {
    return await _authService.getUserTokens();
  }

  // Update user tokens
  Future<bool> updateUserTokens(Map<String, int> tokenUpdates) async {
    return await _authService.updateUserTokens(tokenUpdates);
  }

  // Update verification status
  Future<void> updateVerificationStatus(bool isVerified) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        isVerified: isVerified,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      
      // Update in database
      await _authService.updateProfile(
        name: _currentUser!.name,
        profileImageUrl: _currentUser!.profileImageUrl,
        isVerified: isVerified,
      );
    }
  }

  // Save last login credentials
  Future<void> saveLastLoginCredentials(String email, String password) async {
    await _authService.saveLastLoginCredentials(email, password);
  }

  // Get last login credentials
  Future<Map<String, String>?> getLastLoginCredentials() async {
    return await _authService.loadLastLoginCredentials();
  }

  // Clear last login credentials
  Future<void> clearLastLoginCredentials() async {
    await _authService.clearLastLoginCredentials();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _getErrorMessage(dynamic error) {
    final errorMessage = error.toString();
    
    if (errorMessage.contains('Bu email adresi zaten kayıtlı')) {
      return 'Bu email adresi zaten kayıtlı';
    } else if (errorMessage.contains('Kullanıcı bulunamadı')) {
      return 'Email veya şifre hatalı';
    } else if (errorMessage.contains('Şifre hatalı')) {
      return 'Email veya şifre hatalı';
    } else if (errorMessage.contains('Session yüklenemedi')) {
      return 'Oturum yüklenemedi';
    }
    
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }
}
