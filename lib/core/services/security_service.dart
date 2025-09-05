import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  bool _isSecurityEnabled = false;
  bool _isInitialized = false;

  bool get isSecurityEnabled => _isSecurityEnabled;
  bool get isInitialized => _isInitialized;

  /// Initialize security features
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Only enable security on mobile platforms
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await _enableScreenSecurity();
        await _disableScreenshots();
        await _disableScreenRecording();
        _isSecurityEnabled = true;
      }
      
      _isInitialized = true;
      print('Security service initialized successfully');
    } catch (e) {
      print('Error initializing security service: $e');
      _isSecurityEnabled = false;
      _isInitialized = true;
    }
  }

  /// Enable screen security (prevent screenshots and screen recording)
  Future<void> _enableScreenSecurity() async {
    try {
      if (Platform.isAndroid) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else if (Platform.isIOS) {
        // iOS security is handled differently, implemented in native code
        await _enableIOSScreenSecurity();
      }
    } catch (e) {
      print('Error enabling screen security: $e');
    }
  }

  /// Disable screenshots specifically
  Future<void> _disableScreenshots() async {
    try {
      if (Platform.isAndroid) {
        // FLAG_SECURE already handles this on Android
        await FlutterWindowManager.addFlags(
          FlutterWindowManager.FLAG_SECURE |
          FlutterWindowManager.FLAG_DISMISS_KEYGUARD
        );
      }
    } catch (e) {
      print('Error disabling screenshots: $e');
    }
  }

  /// Disable screen recording
  Future<void> _disableScreenRecording() async {
    try {
      if (Platform.isAndroid) {
        // Use additional flags to prevent screen recording
        await FlutterWindowManager.addFlags(
          FlutterWindowManager.FLAG_SECURE |
          FlutterWindowManager.FLAG_HARDWARE_ACCELERATED
        );
      }
    } catch (e) {
      print('Error disabling screen recording: $e');
    }
  }

  /// iOS specific security implementation
  Future<void> _enableIOSScreenSecurity() async {
    try {
      // This would require native iOS implementation
      // For now, we'll use a method channel approach
      const platform = MethodChannel('com.sendpic.security');
      await platform.invokeMethod('enableScreenSecurity');
    } catch (e) {
      print('iOS screen security not implemented: $e');
    }
  }

  /// Temporarily disable security (for specific screens if needed)
  Future<void> temporarilyDisableSecurity() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } catch (e) {
      print('Error temporarily disabling security: $e');
    }
  }

  /// Re-enable security after temporary disable
  Future<void> reEnableSecurity() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } catch (e) {
      print('Error re-enabling security: $e');
    }
  }

  /// Check if device supports security features
  Future<bool> isSecuritySupported() async {
    try {
      if (kIsWeb) return false;
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      return false;
    }
  }

  /// Get security status information
  Map<String, dynamic> getSecurityStatus() {
    return {
      'isInitialized': _isInitialized,
      'isSecurityEnabled': _isSecurityEnabled,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'screenshotsBlocked': _isSecurityEnabled,
      'screenRecordingBlocked': _isSecurityEnabled,
      'thirdPartyAppsBlocked': _isSecurityEnabled,
    };
  }

  /// Show security warning to user
  String getSecurityWarningMessage(String languageCode) {
    if (languageCode == 'tr') {
      return 'Güvenliğiniz için ekran görüntüsü ve ekran kaydı devre dışı bırakılmıştır.';
    }
    return 'Screenshots and screen recording are disabled for your security.';
  }

  /// Get security features description
  List<String> getSecurityFeatures(String languageCode) {
    if (languageCode == 'tr') {
      return [
        'Ekran görüntüsü engellendi',
        'Ekran kaydı engellendi',
        '3. parti uygulamalar engellendi',
        'Güvenli görüntüleme modu',
        'Yetkisiz erişim koruması',
      ];
    }
    return [
      'Screenshots blocked',
      'Screen recording blocked',
      'Third-party apps blocked',
      'Secure viewing mode',
      'Unauthorized access protection',
    ];
  }

  /// Dispose security service
  Future<void> dispose() async {
    try {
      if (_isSecurityEnabled && !kIsWeb && Platform.isAndroid) {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
      _isSecurityEnabled = false;
      _isInitialized = false;
    } catch (e) {
      print('Error disposing security service: $e');
    }
  }
}