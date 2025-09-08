import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'update_service.dart';
import 'dynamic_config_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  
  Stream<AppNotification> get notificationStream => _notificationController.stream;
  
  late StreamSubscription _updateSubscription;
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Listen to update service events
    _updateSubscription = UpdateService().updateStream.listen(_handleUpdateEvent);
    _isInitialized = true;
  }

  /// Handle update events from UpdateService
  void _handleUpdateEvent(Map<String, dynamic> event) {
    final eventType = event['type'];
    
    switch (eventType) {
      case 'backend_update':
        _showBackendUpdateNotification(event['data']);
        break;
      case 'update_available':
        _showAppUpdateNotification(event['data']);
        break;
      case 'minor_update_available':
        _showMinorUpdateNotification(event);
        break;
      case 'connection_lost':
        _showConnectionLostNotification();
        break;
      case 'connection_restored':
        _showConnectionRestoredNotification();
        break;
    }
  }

  /// Show backend update notification
  void _showBackendUpdateNotification(Map<String, dynamic> data) {
    final notification = AppNotification(
      id: 'backend_update_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.info,
      title: 'Backend Updated',
      message: 'New features and improvements are now available!',
      action: NotificationAction(
        label: 'Refresh',
        onTap: () => _refreshApp(),
      ),
      duration: const Duration(seconds: 5),
      priority: NotificationPriority.medium,
    );
    
    _notificationController.add(notification);
  }

  /// Show app update notification
  void _showAppUpdateNotification(Map<String, dynamic> data) {
    final isForceUpdate = data['force_update'] ?? false;
    final updateUrl = data['update_url'] ?? '';
    
    final notification = AppNotification(
      id: 'app_update_${DateTime.now().millisecondsSinceEpoch}',
      type: isForceUpdate ? NotificationType.warning : NotificationType.info,
      title: isForceUpdate ? 'Update Required' : 'Update Available',
      message: isForceUpdate 
          ? 'Please update to continue using the app'
          : 'A new version is available with exciting features!',
      action: NotificationAction(
        label: 'Update',
        onTap: () => _openUpdateUrl(updateUrl),
      ),
      dismissible: !isForceUpdate,
      duration: isForceUpdate ? null : const Duration(seconds: 10),
      priority: isForceUpdate ? NotificationPriority.high : NotificationPriority.medium,
      data: data,
    );
    
    _notificationController.add(notification);
  }

  /// Show minor update notification
  void _showMinorUpdateNotification(Map<String, dynamic> event) {
    final notification = AppNotification(
      id: 'minor_update_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.success,
      title: 'Backend Enhanced',
      message: 'Backend has been updated with new features. Your app will automatically adapt.',
      duration: const Duration(seconds: 3),
      priority: NotificationPriority.low,
    );
    
    _notificationController.add(notification);
  }

  /// Show connection lost notification
  void _showConnectionLostNotification() {
    final notification = AppNotification(
      id: 'connection_lost',
      type: NotificationType.error,
      title: 'Connection Lost',
      message: 'Unable to connect to server. Trying to reconnect...',
      action: NotificationAction(
        label: 'Retry',
        onTap: () => _retryConnection(),
      ),
      duration: const Duration(seconds: 5),
      priority: NotificationPriority.high,
    );
    
    _notificationController.add(notification);
  }

  /// Show connection restored notification
  void _showConnectionRestoredNotification() {
    final notification = AppNotification(
      id: 'connection_restored',
      type: NotificationType.success,
      title: 'Connection Restored',
      message: 'Successfully reconnected to server.',
      duration: const Duration(seconds: 2),
      priority: NotificationPriority.low,
    );
    
    _notificationController.add(notification);
  }

  /// Show custom notification
  void showNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    NotificationAction? action,
    Duration? duration,
    NotificationPriority priority = NotificationPriority.medium,
    bool dismissible = true,
    Map<String, dynamic>? data,
  }) {
    final notification = AppNotification(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      action: action,
      duration: duration ?? const Duration(seconds: 4),
      priority: priority,
      dismissible: dismissible,
      data: data,
    );
    
    _notificationController.add(notification);
  }

  /// Show success notification
  void showSuccess(String message, {String? title}) {
    showNotification(
      title: title ?? 'Success',
      message: message,
      type: NotificationType.success,
      duration: const Duration(seconds: 3),
    );
  }

  /// Show error notification
  void showError(String message, {String? title}) {
    showNotification(
      title: title ?? 'Error',
      message: message,
      type: NotificationType.error,
      duration: const Duration(seconds: 5),
      priority: NotificationPriority.high,
    );
  }

  /// Show warning notification
  void showWarning(String message, {String? title}) {
    showNotification(
      title: title ?? 'Warning',
      message: message,
      type: NotificationType.warning,
      duration: const Duration(seconds: 4),
      priority: NotificationPriority.medium,
    );
  }

  /// Show info notification
  void showInfo(String message, {String? title}) {
    showNotification(
      title: title ?? 'Info',
      message: message,
      type: NotificationType.info,
      duration: const Duration(seconds: 3),
    );
  }

  /// Refresh app
  void _refreshApp() {
    // Trigger app refresh - you can implement this based on your app architecture
    HapticFeedback.lightImpact();
    // You might want to use a state management solution to trigger refresh
  }

  /// Open update URL
  void _openUpdateUrl(String url) {
    // Implement URL opening logic
    // You can use url_launcher package
    debugPrint('Opening update URL: $url');
  }

  /// Retry connection
  void _retryConnection() async {
    HapticFeedback.lightImpact();
    await DynamicConfigService().autoSwitchUrls();
    // Trigger reconnection logic
  }

  /// Dispose resources
  void dispose() {
    _updateSubscription.cancel();
    _notificationController.close();
    _isInitialized = false;
  }
}

/// Notification model
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final NotificationAction? action;
  final Duration? duration;
  final NotificationPriority priority;
  final bool dismissible;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.action,
    this.duration,
    this.priority = NotificationPriority.medium,
    this.dismissible = true,
    this.data,
  }) : timestamp = DateTime.now();
}

/// Notification action
class NotificationAction {
  final String label;
  final VoidCallback onTap;

  NotificationAction({
    required this.label,
    required this.onTap,
  });
}

/// Notification types
enum NotificationType {
  success,
  error,
  warning,
  info,
}

/// Notification priorities
enum NotificationPriority {
  low,
  medium,
  high,
}