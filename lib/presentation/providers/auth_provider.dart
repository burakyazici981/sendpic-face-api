import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
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
      _currentUser = _authService.currentUser;
      _status = _currentUser != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Session yüklenemedi';
    }
    
    notifyListeners();
  }



  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? profileImageUrl,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(
        email: email,
        password: password,
        name: name,
        profileImageUrl: profileImageUrl,
      );

      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      
      _status = AuthStatus.error;
      _errorMessage = 'Hesap oluşturulamadı';
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
      final user = await _authService.login(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      }
      
      _status = AuthStatus.error;
      _errorMessage = 'Giriş yapılamadı';
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
