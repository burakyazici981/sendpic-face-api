import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/realtime_provider.dart';

class RealtimeStatusWidget extends StatelessWidget {
  const RealtimeStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, child) {
        if (!realtimeProvider.isInitialized) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: realtimeProvider.isConnected 
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: realtimeProvider.isConnected 
                  ? Colors.green
                  : Colors.red,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                realtimeProvider.isConnected 
                    ? Icons.wifi
                    : Icons.wifi_off,
                size: 16,
                color: realtimeProvider.isConnected 
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                realtimeProvider.isConnected ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: realtimeProvider.isConnected 
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RealtimeNotificationBadge extends StatelessWidget {
  final Widget child;
  final String type; // 'messages', 'requests', 'all'
  
  const RealtimeNotificationBadge({
    super.key,
    required this.child,
    this.type = 'all',
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, _) {
        final notificationData = realtimeProvider.getNotificationData();
        
        int count = 0;
        switch (type) {
          case 'messages':
            count = notificationData['unread_messages'] ?? 0;
            break;
          case 'requests':
            count = notificationData['pending_requests'] ?? 0;
            break;
          case 'all':
            count = (notificationData['unread_messages'] ?? 0) + 
                   (notificationData['pending_requests'] ?? 0);
            break;
        }
        
        return Badge(
          isLabelVisible: count > 0,
          label: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red,
          child: child,
        );
      },
    );
  }
}

class RealtimeConnectionIndicator extends StatelessWidget {
  const RealtimeConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, child) {
        if (!realtimeProvider.isInitialized) {
          return const SizedBox.shrink();
        }
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: realtimeProvider.isConnected 
                ? Colors.green
                : Colors.red,
            boxShadow: realtimeProvider.isConnected
                ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

class RealtimeTokenDisplay extends StatelessWidget {
  const RealtimeTokenDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, child) {
        final tokens = realtimeProvider.tokens;
        final totalTokens = tokens.values.fold(0, (sum, token) => sum + token);
        
        if (totalTokens == 0) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.token,
                size: 16,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                totalTokens.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RealtimeUserStatusIndicator extends StatelessWidget {
  final String userId;
  final double size;
  
  const RealtimeUserStatusIndicator({
    super.key,
    required this.userId,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<RealtimeProvider>(
      builder: (context, realtimeProvider, child) {
        final isOnline = realtimeProvider.isUserOnline(userId);
        final lastSeen = realtimeProvider.getUserLastSeen(userId);
        
        return Tooltip(
          message: isOnline 
              ? 'Online'
              : lastSeen != null 
                  ? 'Last seen ${_formatLastSeen(lastSeen)}'
                  : 'Offline',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.green : Colors.grey,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}