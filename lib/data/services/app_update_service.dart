import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  // Server endpoint for version checking
  static const String _versionCheckUrl = 'https://your-api-endpoint.com/api/version';
  
  // App store URLs
  static const String _playStoreUrl = 'https://play.google.com/store/apps/details?id=com.yourcompany.sendpic';
  static const String _appStoreUrl = 'https://apps.apple.com/app/sendpic/id123456789';
  
  PackageInfo? _packageInfo;
  Map<String, dynamic>? _latestVersionInfo;
  
  // Initialize service
  Future<void> initialize() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      print('App version initialized: ${_packageInfo?.version}');
    } catch (e) {
      print('Error initializing app update service: $e');
    }
  }
  
  // Get current app version
  String get currentVersion => _packageInfo?.version ?? '1.0.0';
  
  // Get current build number
  String get currentBuildNumber => _packageInfo?.buildNumber ?? '1';
  
  // Check for updates
  Future<UpdateInfo> checkForUpdates() async {
    try {
      if (_packageInfo == null) {
        await initialize();
      }
      
      final response = await http.get(
        Uri.parse(_versionCheckUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'SendPic/${currentVersion}',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        _latestVersionInfo = json.decode(response.body);
        return _parseUpdateInfo(_latestVersionInfo!);
      } else {
        throw Exception('Failed to check for updates: ${response.statusCode}');
      }
    } catch (e) {
      print('Error checking for updates: $e');
      return UpdateInfo(
        hasUpdate: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        isForced: false,
        updateUrl: '',
        releaseNotes: '',
        error: e.toString(),
      );
    }
  }
  
  // Parse update information from server response
  UpdateInfo _parseUpdateInfo(Map<String, dynamic> data) {
    try {
      final String latestVersion = data['latest_version'] ?? currentVersion;
      final String minRequiredVersion = data['min_required_version'] ?? '1.0.0';
      final bool isForced = _isVersionLower(currentVersion, minRequiredVersion);
      final bool hasUpdate = _isVersionLower(currentVersion, latestVersion);
      
      String updateUrl = '';
      if (Platform.isAndroid) {
        updateUrl = data['android_url'] ?? _playStoreUrl;
      } else if (Platform.isIOS) {
        updateUrl = data['ios_url'] ?? _appStoreUrl;
      }
      
      return UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        isForced: isForced,
        updateUrl: updateUrl,
        releaseNotes: data['release_notes'] ?? '',
        minRequiredVersion: minRequiredVersion,
      );
    } catch (e) {
      print('Error parsing update info: $e');
      return UpdateInfo(
        hasUpdate: false,
        currentVersion: currentVersion,
        latestVersion: currentVersion,
        isForced: false,
        updateUrl: '',
        releaseNotes: '',
        error: e.toString(),
      );
    }
  }
  
  // Compare version strings (returns true if version1 < version2)
  bool _isVersionLower(String version1, String version2) {
    try {
      final v1Parts = version1.split('.').map(int.parse).toList();
      final v2Parts = version2.split('.').map(int.parse).toList();
      
      // Pad shorter version with zeros
      while (v1Parts.length < v2Parts.length) {
        v1Parts.add(0);
      }
      while (v2Parts.length < v1Parts.length) {
        v2Parts.add(0);
      }
      
      for (int i = 0; i < v1Parts.length; i++) {
        if (v1Parts[i] < v2Parts[i]) {
          return true;
        } else if (v1Parts[i] > v2Parts[i]) {
          return false;
        }
      }
      
      return false; // Versions are equal
    } catch (e) {
      print('Error comparing versions: $e');
      return false;
    }
  }
  
  // Open app store for update
  Future<bool> openAppStore([String? customUrl]) async {
    try {
      String url = customUrl ?? '';
      
      if (url.isEmpty) {
        if (Platform.isAndroid) {
          url = _playStoreUrl;
        } else if (Platform.isIOS) {
          url = _appStoreUrl;
        } else {
          return false;
        }
      }
      
      final Uri uri = Uri.parse(url);
      
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('Cannot launch URL: $url');
        return false;
      }
    } catch (e) {
      print('Error opening app store: $e');
      return false;
    }
  }
  
  // Check if app needs immediate update (forced update)
  Future<bool> needsImmediateUpdate() async {
    final updateInfo = await checkForUpdates();
    return updateInfo.isForced;
  }
  
  // Get app information
  Map<String, String> getAppInfo() {
    return {
      'appName': _packageInfo?.appName ?? 'SendPic',
      'packageName': _packageInfo?.packageName ?? 'com.yourcompany.sendpic',
      'version': currentVersion,
      'buildNumber': currentBuildNumber,
      'buildSignature': _packageInfo?.buildSignature ?? '',
    };
  }
  
  // Create mock server response for testing
  static Map<String, dynamic> createMockServerResponse({
    required String latestVersion,
    String? minRequiredVersion,
    String? releaseNotes,
    String? androidUrl,
    String? iosUrl,
  }) {
    return {
      'latest_version': latestVersion,
      'min_required_version': minRequiredVersion ?? '1.0.0',
      'release_notes': releaseNotes ?? 'Bug fixes and improvements',
      'android_url': androidUrl ?? _playStoreUrl,
      'ios_url': iosUrl ?? _appStoreUrl,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

// Update information model
class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final bool isForced;
  final String updateUrl;
  final String releaseNotes;
  final String? minRequiredVersion;
  final String? error;
  
  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.isForced,
    required this.updateUrl,
    required this.releaseNotes,
    this.minRequiredVersion,
    this.error,
  });
  
  bool get isOptional => hasUpdate && !isForced;
  bool get hasError => error != null;
  
  @override
  String toString() {
    return 'UpdateInfo(hasUpdate: $hasUpdate, currentVersion: $currentVersion, '
           'latestVersion: $latestVersion, isForced: $isForced)';
  }
  
  Map<String, dynamic> toJson() {
    return {
      'hasUpdate': hasUpdate,
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'isForced': isForced,
      'updateUrl': updateUrl,
      'releaseNotes': releaseNotes,
      'minRequiredVersion': minRequiredVersion,
      'error': error,
    };
  }
}