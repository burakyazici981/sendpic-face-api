import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/notification_service.dart';

class NotificationOverlay extends StatefulWidget {
  final Widget child;

  const NotificationOverlay({Key? key, required this.child}) : super(key: key);

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay>
    with TickerProviderStateMixin {
  final List<AppNotification> _notifications = [];
  late StreamSubscription _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = NotificationService()
        .notificationStream
        .listen(_handleNotification);
  }

  void _handleNotification(AppNotification notification) {
    setState(() {
      _notifications.add(notification);
    });

    // Auto-dismiss after duration
    if (notification.duration != null) {
      Timer(notification.duration!, () {
        _dismissNotification(notification.id);
      });
    }
  }

  void _dismissNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (_notifications.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Column(
                children: _notifications
                    .map((notification) => NotificationCard(
                          notification: notification,
                          onDismiss: () => _dismissNotification(notification.id),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription.cancel();
    super.dispose();
  }
}

class NotificationCard extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onDismiss;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  Color _getBackgroundColor() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Colors.green.shade50;
      case NotificationType.error:
        return Colors.red.shade50;
      case NotificationType.warning:
        return Colors.orange.shade50;
      case NotificationType.info:
        return Colors.blue.shade50;
    }
  }

  Color _getBorderColor() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  IconData _getIcon() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getBorderColor(),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _getIcon(),
                      color: _getBorderColor(),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.notification.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getBorderColor(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.message,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (widget.notification.action != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    widget.notification.action!.onTap();
                                    _dismiss();
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: _getBorderColor(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    widget.notification.action!.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.notification.dismissible)
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

/// Simple notification banner for quick messages
class NotificationBanner extends StatelessWidget {
  final String message;
  final NotificationType type;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationBanner({
    Key? key,
    required this.message,
    this.type = NotificationType.info,
    this.onTap,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case NotificationType.success:
        backgroundColor = Colors.green;
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case NotificationType.error:
        backgroundColor = Colors.red;
        textColor = Colors.white;
        icon = Icons.error;
        break;
      case NotificationType.warning:
        backgroundColor = Colors.orange;
        textColor = Colors.white;
        icon = Icons.warning;
        break;
      case NotificationType.info:
        backgroundColor = Colors.blue;
        textColor = Colors.white;
        icon = Icons.info;
        break;
    }

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child: Icon(
                    Icons.close,
                    color: textColor,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}