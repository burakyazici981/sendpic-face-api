import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class DynamicConfigService {
  static final DynamicConfigService _instance = DynamicConfigService._internal();
  factory DynamicConfigService() => _instance;
  DynamicConfigService._internal();

  static const String _configKey = 'dynamic_config';
  static const String _lastUpdateKey = 'config_last_update';
  
  Map<String, dynamic> _config = {};
  SharedPreferences? _prefs;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLocalConfig();
  }

  /// Load configuration from local storage
  Future<void> _loadLocalConfig() async {
    final configString = _prefs?.getString(_configKey);
    if (configString != null) {
      try {
        _config = json.decode(configString);
      } catch (e) {
        debugPrint('Error loading local config: $e');
        _config = _getDefaultConfig();
      }
    } else {
      _config = _getDefaultConfig();
    }
  }

  /// Get default configuration
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'api_endpoints': {
        'primary': 'https://sendpicapp-production.up.railway.app',
        'face_recognition': 'https://discerning-gentleness-production.up.railway.app',
        'fallback': 'http://localhost:8000',
        'face_recognition_fallback': 'http://localhost:5050',
      },
      'features': {
        'real_time_updates': true,
        'auto_update_check': true,
        'websocket_enabled': true,
        'offline_mode': false,
      },
      'timeouts': {
        'api_timeout': 30000,
        'websocket_timeout': 5000,
        'retry_attempts': 3,
      },
      'update_intervals': {
        'config_check': 300000, // 5 minutes
        'version_check': 300000, // 5 minutes
        'health_check': 60000,   // 1 minute
      },
    };
  }

  /// Fetch configuration from remote server
  Future<bool> fetchRemoteConfig() async {
    try {
      final primaryUrl = getCurrentApiUrl();
      final response = await http.get(
        Uri.parse('$primaryUrl/api/config'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(milliseconds: getTimeout('api_timeout')));

      if (response.statusCode == 200) {
        final remoteConfig = json.decode(response.body);
        await _mergeAndSaveConfig(remoteConfig);
        return true;
      }
    } catch (e) {
      debugPrint('Error fetching remote config: $e');
      // Try fallback URL
      return await _fetchFromFallback();
    }
    return false;
  }

  /// Fetch from fallback URL
  Future<bool> _fetchFromFallback() async {
    try {
      final fallbackUrl = getFallbackApiUrl();
      final response = await http.get(
        Uri.parse('$fallbackUrl/api/config'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(milliseconds: getTimeout('api_timeout')));

      if (response.statusCode == 200) {
        final remoteConfig = json.decode(response.body);
        await _mergeAndSaveConfig(remoteConfig);
        return true;
      }
    } catch (e) {
      debugPrint('Error fetching from fallback: $e');
    }
    return false;
  }

  /// Merge remote config with local and save
  Future<void> _mergeAndSaveConfig(Map<String, dynamic> remoteConfig) async {
    // Merge configurations (remote takes precedence)
    _config = _deepMerge(_config, remoteConfig);
    
    // Save to local storage
    await _prefs?.setString(_configKey, json.encode(_config));
    await _prefs?.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    
    debugPrint('Configuration updated successfully');
  }

  /// Deep merge two maps
  Map<String, dynamic> _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    final result = Map<String, dynamic>.from(target);
    
    source.forEach((key, value) {
      if (value is Map<String, dynamic> && result[key] is Map<String, dynamic>) {
        result[key] = _deepMerge(result[key], value);
      } else {
        result[key] = value;
      }
    });
    
    return result;
  }

  /// Get current API URL
  String getCurrentApiUrl() {
    return _config['api_endpoints']?['primary'] ?? 'https://sendpicapp-production.up.railway.app';
  }

  /// Get fallback API URL
  String getFallbackApiUrl() {
    return _config['api_endpoints']?['fallback'] ?? 'http://localhost:8000';
  }

  /// Get face recognition API URL
  String getFaceRecognitionUrl() {
    return _config['api_endpoints']?['face_recognition'] ?? 'https://discerning-gentleness-production.up.railway.app';
  }

  /// Get face recognition fallback URL
  String getFaceRecognitionFallbackUrl() {
    return _config['api_endpoints']?['face_recognition_fallback'] ?? 'http://localhost:5050';
  }

  /// Check if feature is enabled
  bool isFeatureEnabled(String feature) {
    return _config['features']?[feature] ?? false;
  }

  /// Get timeout value
  int getTimeout(String timeoutType) {
    return _config['timeouts']?[timeoutType] ?? 30000;
  }

  /// Get update interval
  int getUpdateInterval(String intervalType) {
    return _config['update_intervals']?[intervalType] ?? 300000;
  }

  /// Switch to fallback URLs
  Future<void> switchToFallback() async {
    final currentConfig = Map<String, dynamic>.from(_config);
    currentConfig['api_endpoints']['primary'] = getFallbackApiUrl();
    currentConfig['api_endpoints']['face_recognition'] = getFaceRecognitionFallbackUrl();
    
    _config = currentConfig;
    await _prefs?.setString(_configKey, json.encode(_config));
    
    debugPrint('Switched to fallback URLs');
  }

  /// Switch back to primary URLs
  Future<void> switchToPrimary() async {
    final defaultConfig = _getDefaultConfig();
    final currentConfig = Map<String, dynamic>.from(_config);
    currentConfig['api_endpoints']['primary'] = defaultConfig['api_endpoints']['primary'];
    currentConfig['api_endpoints']['face_recognition'] = defaultConfig['api_endpoints']['face_recognition'];
    
    _config = currentConfig;
    await _prefs?.setString(_configKey, json.encode(_config));
    
    debugPrint('Switched back to primary URLs');
  }

  /// Test API connectivity
  Future<bool> testApiConnectivity([String? customUrl]) async {
    final testUrl = customUrl ?? getCurrentApiUrl();
    try {
      final response = await http.get(
        Uri.parse('$testUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(milliseconds: getTimeout('api_timeout')));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API connectivity test failed: $e');
      return false;
    }
  }

  /// Auto-switch URLs based on connectivity
  Future<void> autoSwitchUrls() async {
    final primaryWorking = await testApiConnectivity();
    
    if (!primaryWorking) {
      debugPrint('Primary API not responding, switching to fallback');
      await switchToFallback();
      
      final fallbackWorking = await testApiConnectivity();
      if (!fallbackWorking) {
        debugPrint('Both primary and fallback APIs are not responding');
      }
    }
  }

  /// Get last config update time
  DateTime? getLastUpdateTime() {
    final timestamp = _prefs?.getInt(_lastUpdateKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  /// Check if config needs update
  bool needsConfigUpdate() {
    final lastUpdate = getLastUpdateTime();
    if (lastUpdate == null) return true;
    
    final updateInterval = getUpdateInterval('config_check');
    return DateTime.now().difference(lastUpdate).inMilliseconds > updateInterval;
  }

  /// Get full configuration
  Map<String, dynamic> getConfig() => Map<String, dynamic>.from(_config);

  /// Update specific config value
  Future<void> updateConfig(String key, dynamic value) async {
    _config[key] = value;
    await _prefs?.setString(_configKey, json.encode(_config));
  }

  /// Reset to default configuration
  Future<void> resetToDefault() async {
    _config = _getDefaultConfig();
    await _prefs?.setString(_configKey, json.encode(_config));
    await _prefs?.remove(_lastUpdateKey);
    debugPrint('Configuration reset to default');
  }
}