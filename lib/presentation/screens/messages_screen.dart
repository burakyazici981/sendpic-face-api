import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/content_provider.dart';
import '../providers/realtime_provider.dart';
import '../../data/models/friendship_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/user_model.dart';
import '../widgets/loading_widget.dart';
import '../widgets/realtime_status_widget.dart';
import '../widgets/profile_image_picker.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await contentProvider.loadFriendships(authProvider.currentUser!.id);
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            const Text(
              'Messages',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            RealtimeConnectionIndicator(),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C5CE7),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Consumer<RealtimeProvider>(
              builder: (context, realtimeProvider, child) {
                return RealtimeNotificationBadge(
                  type: 'messages',
                  child: const Tab(text: 'Friends'),
                );
              },
            ),
            Consumer<RealtimeProvider>(
              builder: (context, realtimeProvider, child) {
                return RealtimeNotificationBadge(
                  type: 'requests',
                  child: const Tab(text: 'Requests'),
                );
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsTab(),
                _buildRequestsTab(),
              ],
            ),
    );
  }

  Widget _buildFriendsTab() {
    return Consumer<ContentProvider>(builder: (context, contentProvider, child) {
      final friends = contentProvider.acceptedFriends;
      
      if (friends.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No friends yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Like content in the Discover tab to\nsend friend requests',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }
      
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friendship = friends[index];
          return _buildFriendTile(friendship);
        },
      );
    });
  }

  Widget _buildRequestsTab() {
    return Consumer<ContentProvider>(builder: (context, contentProvider, child) {
      final requests = contentProvider.pendingRequests;
      
      if (requests.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No pending requests',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        );
      }
      
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestTile(request);
        },
      );
    });
  }

  Widget _buildFriendTile(FriendshipModel friendship) {
    return Consumer<AuthProvider>(builder: (context, authProvider, child) {
      final currentUserId = authProvider.currentUser?.id ?? '';
      final friendId = friendship.requesterId == currentUserId 
          ? friendship.addresseeId 
          : friendship.requesterId;
      
      // Simplified implementation - show friend ID directly
      return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF6C5CE7),
                backgroundImage: null,
                child: Text(
                  friendId.isNotEmpty ? friendId[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                'Arkadaş $friendId',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Henüz bio eklenmemiş',
                style: const TextStyle(color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(
                Icons.chat_bubble_outline,
                color: Color(0xFF6C5CE7),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      friend: friend,
                      currentUserId: currentUserId,
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    });
  }

  Widget _buildRequestTile(FriendshipModel request) {
    return Consumer2<AuthProvider, ContentProvider>(
      builder: (context, authProvider, contentProvider, child) {
        final currentUserId = authProvider.currentUser?.id ?? '';
        final requesterId = request.requesterId;
        
        // Only show requests where current user is the addressee
        if (request.addresseeId != currentUserId) {
          return const SizedBox.shrink();
        }
        
        // Simplified implementation
        return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF6C5CE7),
                  backgroundImage: null,
                  child: Text(
                          requesterId.isNotEmpty ? requesterId[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  'Kullanıcı $requesterId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Arkadaş isteği gönderdi',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final success = await contentProvider.acceptFriendRequest(
                          request.id,
                          currentUserId,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Arkadaş isteği kabul edildi'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.check,
                        color: Colors.green,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final success = await contentProvider.rejectFriendRequest(
                          request.id,
                          currentUserId,
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Arkadaş isteği reddedildi'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}