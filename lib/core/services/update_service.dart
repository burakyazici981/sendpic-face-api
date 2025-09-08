import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  WebSocketChannel? _channel;
  Timer? _updateCheckTimer;
  final StreamController<Map<String, dynamic>> _updateStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get updateStream => _updateStreamController.stream;

  static const String currentVersion = '1.0.0';
  bool _isConnected = false;

  /// Initialize the update service
  Future<void> initialize(String userId) async {
    await _connectWebSocket(userId);
    _startPeriodicUpdateCheck();
  }

  /// Connect to WebSocket for real-time updates
  Future<void> _connectWebSocket(String userId) async {
    try {
      final wsUrl = ApiConfig.baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/$userId'),
      );

      _channel!.stream.listen(
        (data) {
          try {
            final message = json.decode(data);
            _handleWebSocketMessage(message);
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect(userId);
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect(userId);
        },
      );

      _isConnected = true;
      debugPrint('WebSocket connected successfully');
    } catch (e) {
      debugPrint('Failed to connect WebSocket: $e');
      _scheduleReconnect(userId);
    }
  }

  /// Handle incoming WebSocket messages
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final messageType = message['type'];
    
    switch (messageType) {
      case 'connection':
        debugPrint('Connected to real-time updates');
        break;
      case 'system_update':
        _updateStreamController.add({
          'type': 'backend_update',
          'data': message['data'],
          'timestamp': message['timestamp'],
        });
        break;
      case 'pong':
        // Handle ping-pong for connection health
        break;
      default:
        _updateStreamController.add(message);
    }
  }

  /// Schedule WebSocket reconnection
  void _scheduleReconnect(String userId) {
    Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        _connectWebSocket(userId);
      }
    });
  }

  /// Start periodic update checking
  void _startPeriodicUpdateCheck() {
    _updateCheckTimer = Timer.periodic(
      const Duration(minutes: 5), // Check every 5 minutes
      (timer) => checkForUpdates(),
    );
  }

  /// Check for backend updates
  Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/check-updates?client_version=$currentVersion'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final updateInfo = json.decode(response.body);
        
        if (updateInfo['needs_update'] == true) {
          _updateStreamController.add({
            'type': 'update_available',
            'data': updateInfo,
          });
        }
        
        return updateInfo;
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  /// Get current API version from backend
  Future<Map<String, dynamic>?> getApiVersion() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/version'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting API version: $e');
    }
    return null;
  }

  /// Send ping to keep WebSocket alive
  void sendPing() {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(json.encode({
        'type': 'ping',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  /// Check if backend is compatible with current app version
  Future<bool> isBackendCompatible() async {
    final versionInfo = await getApiVersion();
    if (versionInfo == null) return false;
    
    // Simple version comparison - you can make this more sophisticated
    final backendVersion = versionInfo['version'] as String;
    return _isVersionCompatible(currentVersion, backendVersion);
  }

  /// Simple version compatibility check
  bool _isVersionCompatible(String clientVersion, String serverVersion) {
    final clientParts = clientVersion.split('.').map(int.parse).toList();
    final serverParts = serverVersion.split('.').map(int.parse).toList();
    
    // Major version must match
    if (clientParts[0] != serverParts[0]) return false;
    
    // Minor version - server can be higher
    if (serverParts[1] > clientParts[1]) {
      _updateStreamController.add({
        'type': 'minor_update_available',
        'client_version': clientVersion,
        'server_version': serverVersion,
      });
    }
    
    return true;
  }

  /// Dispose resources
  void dispose() {
    _updateCheckTimer?.cancel();
    _channel?.sink.close();
    _updateStreamController.close();
    _isConnected = false;
  }

  /// Get connection status
  bool get isConnected => _isConnected;
}