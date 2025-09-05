import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/content_model.dart';
import '../models/message_model.dart';
import '../models/friendship_model.dart';

class SupabaseRealtimeService {
  static final SupabaseRealtimeService _instance = SupabaseRealtimeService._internal();
  factory SupabaseRealtimeService() => _instance;
  SupabaseRealtimeService._internal();

  SupabaseClient get _client => SupabaseConfig.client;
  
  // Stream controllers for real-time updates
  final StreamController<List<ContentModel>> _postsController = StreamController<List<ContentModel>>.broadcast();
  final StreamController<List<MessageModel>> _messagesController = StreamController<List<MessageModel>>.broadcast();
  final StreamController<List<FriendshipModel>> _friendshipsController = StreamController<List<FriendshipModel>>.broadcast();
  final StreamController<Map<String, int>> _tokensController = StreamController<Map<String, int>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Subscription references
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _friendshipsChannel;
  RealtimeChannel? _tokensChannel;
  RealtimeChannel? _userStatusChannel;
  
  // Current user ID
  String? _currentUserId;
  
  // Getters for streams
  Stream<List<ContentModel>> get postsStream => _postsController.stream;
  Stream<List<MessageModel>> get messagesStream => _messagesController.stream;
  Stream<List<FriendshipModel>> get friendshipsStream => _friendshipsController.stream;
  Stream<Map<String, int>> get tokensStream => _tokensController.stream;
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusController.stream;
  
  // Initialize real-time subscriptions
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    
    await _subscribeToUserPosts(userId);
    await _subscribeToUserMessages(userId);
    await _subscribeToUserFriendships(userId);
    await _subscribeToUserTokens(userId);
    await _subscribeToUserStatus(userId);
  }
  
  // Subscribe to user's posts updates
  Future<void> _subscribeToUserPosts(String userId) async {
    try {
      _postsChannel = _client.channel('posts:user_id=eq.$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) async {
            await _handlePostsChange(payload);
          },
        )
        ..subscribe();
    } catch (e) {
      print('Error subscribing to posts: $e');
    }
  }
  
  // Subscribe to user's messages
  Future<void> _subscribeToUserMessages(String userId) async {
    try {
      _messagesChannel = _client.channel('messages:user_$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'recipient_id', value: userId),
          callback: (payload) async {
            await _handleMessagesChange(payload);
          },
        )
        ..subscribe();
    } catch (e) {
      print('Error subscribing to messages: $e');
    }
  }
  
  // Subscribe to user's friendships
  Future<void> _subscribeToUserFriendships(String userId) async {
    try {
      _friendshipsChannel = _client.channel('friendships:user_$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'requester_id', value: userId),
          callback: (payload) async {
            await _handleFriendshipsChange(payload);
          },
        )
        ..subscribe();
    } catch (e) {
      print('Error subscribing to friendships: $e');
    }
  }
  
  // Subscribe to user's token updates
  Future<void> _subscribeToUserTokens(String userId) async {
    try {
      _tokensChannel = _client.channel('tokens:user_id=eq.$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_tokens',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) async {
            await _handleTokensChange(payload);
          },
        )
        ..subscribe();
    } catch (e) {
      print('Error subscribing to tokens: $e');
    }
  }
  
  // Subscribe to user status updates (online/offline)
  Future<void> _subscribeToUserStatus(String userId) async {
    try {
      _userStatusChannel = _client.channel('user_status:user_$userId')
        ..onPresenceSync((payload) {
          _handleUserStatusChange([]);
        })
        ..onPresenceJoin((payload) {
          _handleUserStatusChange([]);
        })
        ..onPresenceLeave((payload) {
          _handleUserStatusChange([]);
        })
        ..subscribe();
      
      // Track current user's presence
      await _userStatusChannel?.track({
        'user_id': userId,
        'online_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error subscribing to user status: $e');
    }
  }
  
  // Handle posts changes
  Future<void> _handlePostsChange(PostgresChangePayload payload) async {
    try {
      // Fetch updated posts list
      final response = await _client
          .from('posts')
          .select('''
            *,
            users!posts_user_id_fkey(
              id,
              name,
              profile_image_url
            )
          ''')
          .eq('user_id', _currentUserId!)
          .order('created_at', ascending: false);
      
      final posts = response
          .map((json) => ContentModel.fromSupabaseJson(json))
          .toList();
      
      _postsController.add(posts);
    } catch (e) {
      print('Error handling posts change: $e');
    }
  }
  
  // Handle messages changes
  Future<void> _handleMessagesChange(PostgresChangePayload payload) async {
    try {
      // Fetch updated messages list
      final response = await _client
          .from('messages')
          .select('''
            *,
            sender:users!messages_sender_id_fkey(
              id,
              name,
              profile_image_url
            ),
            recipient:users!messages_recipient_id_fkey(
              id,
              name,
              profile_image_url
            )
          ''')
          .or('sender_id.eq.$_currentUserId,recipient_id.eq.$_currentUserId')
          .order('created_at', ascending: false);
      
      final messages = response
          .map((json) => MessageModel.fromSupabaseJson(json))
          .toList();
      
      _messagesController.add(messages);
    } catch (e) {
      print('Error handling messages change: $e');
    }
  }
  
  // Handle friendships changes
  Future<void> _handleFriendshipsChange(PostgresChangePayload payload) async {
    try {
      // Fetch updated friendships list
      final response = await _client
          .from('friendships')
          .select('''
            *,
            requester:users!friendships_requester_id_fkey(
              id,
              name,
              profile_image_url
            ),
            addressee:users!friendships_addressee_id_fkey(
              id,
              name,
              profile_image_url
            )
          ''')
          .or('requester_id.eq.$_currentUserId,addressee_id.eq.$_currentUserId')
          .order('created_at', ascending: false);
      
      final friendships = response
          .map((json) => FriendshipModel.fromSupabaseJson(json))
          .toList();
      
      _friendshipsController.add(friendships);
    } catch (e) {
      print('Error handling friendships change: $e');
    }
  }
  
  // Handle tokens changes
  Future<void> _handleTokensChange(PostgresChangePayload payload) async {
    try {
      // Fetch updated token balance
      final response = await _client
          .from('user_tokens')
          .select()
          .eq('user_id', _currentUserId!)
          .single();
      
      final tokens = <String, int>{
        'photo_tokens': (response['photo_tokens'] as int?) ?? 0,
        'video_tokens': (response['video_tokens'] as int?) ?? 0,
        'premium_tokens': (response['premium_tokens'] as int?) ?? 0,
      };
      
      _tokensController.add(tokens);
    } catch (e) {
      print('Error handling tokens change: $e');
    }
  }
  
  // Handle user status changes
  void _handleUserStatusChange(List<Map<String, dynamic>> payload) {
    try {
      final userStatuses = <String, dynamic>{};
      
      for (final presence in payload) {
        final userId = presence['user_id'] as String?;
        if (userId != null) {
          userStatuses[userId] = {
            'online': true,
            'last_seen': presence['online_at'],
          };
        }
      }
      
      _userStatusController.add(userStatuses);
    } catch (e) {
      print('Error handling user status change: $e');
    }
  }
  
  // Subscribe to public posts feed
  Future<void> subscribeToPublicPosts() async {
    try {
      _client.channel('public_posts')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'is_public', value: true),
          callback: (payload) async {
            // Handle new public post
            await _handleNewPublicPost(payload);
          },
        )
        ..subscribe();
    } catch (e) {
      print('Error subscribing to public posts: $e');
    }
  }
  
  // Handle new public post
  Future<void> _handleNewPublicPost(PostgresChangePayload payload) async {
    try {
      // You can emit notifications or update feeds here
      print('New public post: ${payload.newRecord}');
    } catch (e) {
      print('Error handling new public post: $e');
    }
  }
  
  // Send real-time message
  Future<bool> sendRealtimeMessage({
    required String recipientId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      if (_currentUserId == null) return false;
      
      await _client.from('messages').insert({
        'sender_id': _currentUserId,
        'recipient_id': recipientId,
        'content': content,
        'message_type': messageType,
        'media_url': mediaUrl,
      });
      
      return true;
    } catch (e) {
      print('Error sending realtime message: $e');
      return false;
    }
  }
  
  // Update user online status
  Future<void> updateUserStatus(bool isOnline) async {
    try {
      if (_userStatusChannel != null && _currentUserId != null) {
        if (isOnline) {
          await _userStatusChannel!.track({
            'user_id': _currentUserId,
            'online_at': DateTime.now().toIso8601String(),
          });
        } else {
          await _userStatusChannel!.untrack();
        }
      }
    } catch (e) {
      print('Error updating user status: $e');
    }
  }
  
  // Cleanup subscriptions
  Future<void> dispose() async {
    try {
      await _postsChannel?.unsubscribe();
      await _messagesChannel?.unsubscribe();
      await _friendshipsChannel?.unsubscribe();
      await _tokensChannel?.unsubscribe();
      await _userStatusChannel?.unsubscribe();
      
      await _postsController.close();
      await _messagesController.close();
      await _friendshipsController.close();
      await _tokensController.close();
      await _userStatusController.close();
    } catch (e) {
      print('Error disposing realtime service: $e');
    }
  }
  
  // Get current connection status
  bool get isConnected {
    return _client.realtime.isConnected;
  }
  
  // Reconnect if disconnected
  Future<void> reconnect() async {
    try {
      if (_currentUserId != null) {
        await initialize(_currentUserId!);
      }
    } catch (e) {
      print('Error reconnecting: $e');
    }
  }
}