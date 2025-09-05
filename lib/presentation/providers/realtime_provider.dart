import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/services/supabase_realtime_service.dart';
import '../../data/services/supabase_auth_service.dart';
import '../../data/models/content_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/friendship_model.dart';

class RealtimeProvider extends ChangeNotifier {
  final SupabaseRealtimeService _realtimeService = SupabaseRealtimeService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  
  // Stream subscriptions
  StreamSubscription<List<ContentModel>>? _postsSubscription;
  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  StreamSubscription<List<FriendshipModel>>? _friendshipsSubscription;
  StreamSubscription<Map<String, int>>? _tokensSubscription;
  StreamSubscription<Map<String, dynamic>>? _userStatusSubscription;
  
  // Current data
  List<ContentModel> _posts = [];
  List<MessageModel> _messages = [];
  List<FriendshipModel> _friendships = [];
  Map<String, int> _tokens = {};
  Map<String, dynamic> _userStatuses = {};
  
  // Connection status
  bool _isConnected = false;
  bool _isInitialized = false;
  
  // Getters
  List<ContentModel> get posts => _posts;
  List<MessageModel> get messages => _messages;
  List<FriendshipModel> get friendships => _friendships;
  Map<String, int> get tokens => _tokens;
  Map<String, dynamic> get userStatuses => _userStatuses;
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  
  // Initialize real-time connections
  Future<void> initialize() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('No user logged in, cannot initialize realtime');
        return;
      }
      
      // Initialize realtime service
      await _realtimeService.initialize(user.id);
      
      // Subscribe to streams
      _subscribeToStreams();
      
      // Subscribe to public posts
      await _realtimeService.subscribeToPublicPosts();
      
      _isConnected = _realtimeService.isConnected;
      _isInitialized = true;
      
      notifyListeners();
      
      print('Realtime provider initialized successfully');
    } catch (e) {
      print('Error initializing realtime provider: $e');
      _isConnected = false;
      _isInitialized = false;
      notifyListeners();
    }
  }
  
  // Subscribe to all real-time streams
  void _subscribeToStreams() {
    // Subscribe to posts updates
    _postsSubscription = _realtimeService.postsStream.listen(
      (posts) {
        _posts = posts;
        notifyListeners();
      },
      onError: (error) {
        print('Error in posts stream: $error');
      },
    );
    
    // Subscribe to messages updates
    _messagesSubscription = _realtimeService.messagesStream.listen(
      (messages) {
        _messages = messages;
        notifyListeners();
      },
      onError: (error) {
        print('Error in messages stream: $error');
      },
    );
    
    // Subscribe to friendships updates
    _friendshipsSubscription = _realtimeService.friendshipsStream.listen(
      (friendships) {
        _friendships = friendships;
        notifyListeners();
      },
      onError: (error) {
        print('Error in friendships stream: $error');
      },
    );
    
    // Subscribe to tokens updates
    _tokensSubscription = _realtimeService.tokensStream.listen(
      (tokens) {
        _tokens = tokens;
        notifyListeners();
      },
      onError: (error) {
        print('Error in tokens stream: $error');
      },
    );
    
    // Subscribe to user status updates
    _userStatusSubscription = _realtimeService.userStatusStream.listen(
      (userStatuses) {
        _userStatuses = userStatuses;
        notifyListeners();
      },
      onError: (error) {
        print('Error in user status stream: $error');
      },
    );
  }
  
  // Send real-time message
  Future<bool> sendMessage({
    required String recipientId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      return await _realtimeService.sendRealtimeMessage(
        recipientId: recipientId,
        content: content,
        messageType: messageType,
        mediaUrl: mediaUrl,
      );
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }
  
  // Update user online status
  Future<void> setUserOnline(bool isOnline) async {
    try {
      await _realtimeService.updateUserStatus(isOnline);
      _isConnected = _realtimeService.isConnected;
      notifyListeners();
    } catch (e) {
      print('Error updating user status: $e');
    }
  }
  
  // Check if user is online
  bool isUserOnline(String userId) {
    return _userStatuses.containsKey(userId) && 
           _userStatuses[userId]['online'] == true;
  }
  
  // Get user's last seen time
  DateTime? getUserLastSeen(String userId) {
    if (_userStatuses.containsKey(userId)) {
      final lastSeen = _userStatuses[userId]['last_seen'];
      if (lastSeen != null) {
        return DateTime.tryParse(lastSeen);
      }
    }
    return null;
  }
  
  // Get unread messages count
  int getUnreadMessagesCount() {
    return _messages.where((message) => 
      message.receiverId == _authService.currentUser?.id && 
      !message.isRead
    ).length;
  }
  
  // Get pending friend requests count
  int getPendingFriendRequestsCount() {
    return _friendships.where((friendship) => 
      friendship.addresseeId == _authService.currentUser?.id && 
      friendship.status == 'pending'
    ).length;
  }
  
  // Get messages for specific user
  List<MessageModel> getMessagesForUser(String userId) {
    return _messages.where((message) => 
      (message.senderId == userId && message.receiverId == _authService.currentUser?.id) ||
      (message.senderId == _authService.currentUser?.id && message.receiverId == userId)
    ).toList();
  }
  
  // Get friends list
  List<FriendshipModel> getFriends() {
    return _friendships.where((friendship) => 
      friendship.status == 'accepted'
    ).toList();
  }
  
  // Get pending friend requests
  List<FriendshipModel> getPendingRequests() {
    return _friendships.where((friendship) => 
      friendship.addresseeId == _authService.currentUser?.id && 
      friendship.status == 'pending'
    ).toList();
  }
  
  // Get sent friend requests
  List<FriendshipModel> getSentRequests() {
    return _friendships.where((friendship) => 
      friendship.requesterId == _authService.currentUser?.id && 
      friendship.status == 'pending'
    ).toList();
  }
  
  // Reconnect to real-time services
  Future<void> reconnect() async {
    try {
      await _realtimeService.reconnect();
      _isConnected = _realtimeService.isConnected;
      notifyListeners();
    } catch (e) {
      print('Error reconnecting: $e');
      _isConnected = false;
      notifyListeners();
    }
  }
  
  // Check connection status periodically
  Timer? _connectionTimer;
  
  void startConnectionMonitoring() {
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final wasConnected = _isConnected;
      _isConnected = _realtimeService.isConnected;
      
      if (wasConnected != _isConnected) {
        notifyListeners();
        
        if (!_isConnected) {
          print('Real-time connection lost, attempting to reconnect...');
          reconnect();
        }
      }
    });
  }
  
  void stopConnectionMonitoring() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }
  
  // Clear all data
  void clearData() {
    _posts.clear();
    _messages.clear();
    _friendships.clear();
    _tokens.clear();
    _userStatuses.clear();
    _isConnected = false;
    _isInitialized = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    // Cancel all subscriptions
    _postsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _friendshipsSubscription?.cancel();
    _tokensSubscription?.cancel();
    _userStatusSubscription?.cancel();
    
    // Stop connection monitoring
    stopConnectionMonitoring();
    
    // Dispose realtime service
    _realtimeService.dispose();
    
    super.dispose();
  }
  
  // Force refresh all data
  Future<void> refreshAllData() async {
    try {
      if (_isInitialized) {
        await _realtimeService.reconnect();
        _isConnected = _realtimeService.isConnected;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }
  
  // Get notification data for UI
  Map<String, dynamic> getNotificationData() {
    return {
      'unread_messages': getUnreadMessagesCount(),
      'pending_requests': getPendingFriendRequestsCount(),
      'is_connected': _isConnected,
      'total_tokens': _tokens.values.fold(0, (sum, tokens) => sum + tokens),
    };
  }
}