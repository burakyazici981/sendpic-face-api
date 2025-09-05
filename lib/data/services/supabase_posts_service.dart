import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/content_model.dart';
import '../models/content_recipient_model.dart';
import '../../core/config/supabase_config.dart';

class SupabasePostsService {
  static final SupabasePostsService _instance = SupabasePostsService._internal();
  factory SupabasePostsService() => _instance;
  SupabasePostsService._internal();

  SupabaseClient get _client => SupabaseConfig.client;

  // Create a new post
  Future<String?> createPost({
    required String userId,
    String? content,
    String? mediaUrl,
    String? mediaType,
    bool isPublic = true,
  }) async {
    try {
      // Insert post into database
      final response = await _client.from('posts').insert({
        'user_id': userId,
        'content_type': mediaType ?? 'photo',
        'content_url': mediaUrl,
        'thumbnail_url': mediaType == 'video' ? mediaUrl : null,
        'caption': content,
        'is_public': isPublic,
      }).select().single();

      return response['id'] as String;
    } catch (e) {
      print('Error creating post: $e');
      return null;
    }
  }

  // Send post to specific user
  Future<bool> sendToUser({
    required String postId,
    required String recipientId,
  }) async {
    try {
      final post = await _client
          .from('posts')
          .select()
          .eq('id', postId)
          .single();
      
      final senderId = post['user_id'] as String;
      final contentType = post['content_type'] as String;
      final tokensUsed = contentType == 'photo' ? 1 : 2;
      
      await _client.from('content_recipients').insert({
        'content_id': postId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'tokens_used': tokensUsed,
      });
      
      return true;
    } catch (e) {
      print('Error sending to user: $e');
      return false;
    }
  }

  // Send post to random users
  Future<bool> sendToRandomUsers({
    required String postId,
    required int count,
  }) async {
    try {
      final post = await _client
          .from('posts')
          .select()
          .eq('id', postId)
          .single();
      
      final senderId = post['user_id'] as String;
      final contentType = post['content_type'] as String;
      final tokensUsed = contentType == 'photo' ? 1 : 2;
      
      // Get random recipients
      final recipientsResponse = await _client
          .from('users')
          .select('id')
          .neq('id', senderId)
          .limit(count);
      
      final recipients = recipientsResponse.map((r) => r['id'] as String).toList();
      
      // Create content recipient records
      final contentRecipients = recipients.map((recipientId) => {
        'content_id': postId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'tokens_used': tokensUsed,
      }).toList();
      
      await _client.from('content_recipients').insert(contentRecipients);
      
      return true;
    } catch (e) {
      print('Error sending to random users: $e');
      return false;
    }
  }

  // Get user's posts
  Future<List<ContentModel>> getUserPosts(String userId) async {
    try {
      final response = await _client
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map((json) => ContentModel.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      print('Error getting user posts: $e');
      return [];
    }
  }

  // Get public posts (feed)
  Future<List<ContentModel>> getPublicPosts({int limit = 20, int offset = 0}) async {
    try {
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
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response
          .map((json) => ContentModel.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      print('Error getting public posts: $e');
      return [];
    }
  }

  // Update post
  Future<bool> updatePost({
    required String postId,
    String? caption,
    bool? isPublic,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (caption != null) updates['caption'] = caption;
      if (isPublic != null) updates['is_public'] = isPublic;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client
          .from('posts')
          .update(updates)
          .eq('id', postId);

      return true;
    } catch (e) {
      print('Error updating post: $e');
      return false;
    }
  }

  // Delete post
  Future<bool> deletePost(String postId) async {
    try {
      // First get the post to delete associated files
      final post = await _client
          .from('posts')
          .select()
          .eq('id', postId)
          .single();

      // Delete from storage
      final contentUrl = post['content_url'] as String;
      final fileName = contentUrl.split('/').last;
      final bucket = post['content_type'] == 'photo' ? 'photos' : 'videos';
      
      await _client.storage
          .from(bucket)
          .remove([fileName]);

      // Delete from database
      await _client
          .from('posts')
          .delete()
          .eq('id', postId);

      return true;
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }

  // Upload image to Supabase storage
  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final response = await _client.storage
          .from('photos')
          .upload(fileName, imageFile);
      
      if (response.isNotEmpty) {
        final publicUrl = _client.storage
            .from('photos')
            .getPublicUrl(fileName);
        return publicUrl;
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Upload video to Supabase storage
  Future<String?> uploadVideo(File videoFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final response = await _client.storage
          .from('videos')
          .upload(fileName, videoFile);
      
      if (response.isNotEmpty) {
        final publicUrl = _client.storage
            .from('videos')
            .getPublicUrl(fileName);
        return publicUrl;
      }
      return null;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  // Create content
  Future<ContentModel?> createContent({
    required String senderId,
    required String mediaUrl,
    required String mediaType,
  }) async {
    try {
      final response = await _client.from('content').insert({
        'sender_id': senderId,
        'media_url': mediaUrl,
        'media_type': mediaType,
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      return ContentModel.fromJson(response);
    } catch (e) {
      print('Error creating content: $e');
      return null;
    }
  }

  // Send random content
  Future<bool> sendRandomContent({
    required String contentId,
    required String senderId,
  }) async {
    try {
      // Get random user (excluding sender)
      final recipientsResponse = await _client
          .from('users')
          .select('id')
          .neq('id', senderId)
          .limit(1);

      if (recipientsResponse.isEmpty) {
        return false;
      }

      final recipientId = recipientsResponse.first['id'] as String;

      // Create content recipient
      await _client.from('content_recipients').insert({
        'content_id': contentId,
        'recipient_id': recipientId,
        'is_viewed': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error sending random content: $e');
      return false;
    }
  }

  // Send random content (old version for compatibility)
  Future<Map<String, dynamic>?> sendRandomContentOld({
    required String contentId,
    required int recipientCount,
    required String senderId,
  }) async {
    try {
      // Get sender's token balance
      final tokenResponse = await _client
          .from('user_tokens')
          .select()
          .eq('user_id', senderId)
          .single();

      final photoTokens = tokenResponse['photo_tokens'] as int;
      final videoTokens = tokenResponse['video_tokens'] as int;

      // Get post details
      final post = await _client
          .from('posts')
          .select()
          .eq('id', contentId)
          .single();

      final contentType = post['content_type'] as String;
      final requiredTokens = _getRequiredTokens(recipientCount, contentType);
      final availableTokens = contentType == 'photo' ? photoTokens : videoTokens;

      if (availableTokens < requiredTokens) {
        return {
          'success': false,
          'error': 'Yetersiz token. Gerekli: $requiredTokens, Mevcut: $availableTokens',
        };
      }

      // Get random recipients (excluding sender)
      final recipientsResponse = await _client
          .from('users')
          .select('id')
          .neq('id', senderId)
          .limit(recipientCount);

      final recipients = recipientsResponse.map((r) => r['id'] as String).toList();

      if (recipients.length < recipientCount) {
        return {
          'success': false,
          'error': 'Yeterli alıcı bulunamadı',
        };
      }

      // Create content recipient records
      final contentRecipients = recipients.map((recipientId) => {
        'content_id': contentId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'tokens_used': requiredTokens ~/ recipientCount,
      }).toList();

      await _client.from('content_recipients').insert(contentRecipients);

      // Deduct tokens
      final tokenKey = contentType == 'photo' ? 'photo_tokens' : 'video_tokens';
      await _client
          .from('user_tokens')
          .update({
            tokenKey: availableTokens - requiredTokens,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', senderId);

      // Record transaction
      await _client.from('token_transactions').insert({
        'user_id': senderId,
        'transaction_type': 'spent',
        'token_type': '${contentType}_tokens',
        'amount': requiredTokens,
        'description': 'Random content sent to $recipientCount recipients',
      });

      return {
        'success': true,
        'recipients_count': recipients.length,
        'tokens_used': requiredTokens,
      };
    } catch (e) {
      print('Error sending random content: $e');
      return {
        'success': false,
        'error': 'Gönderim sırasında hata oluştu: $e',
      };
    }
  }

  // Get received content
  Future<List<ContentRecipientModel>> getReceivedContent(String userId) async {
    try {
      final response = await _client
          .from('content_recipients')
          .select('''
            *,
            posts!content_recipients_content_id_fkey(
              *,
              users!posts_user_id_fkey(
                id,
                name,
                profile_image_url
              )
            )
          ''')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false);

      return response
          .map((json) => ContentRecipientModel.fromSupabaseJson(json))
          .toList();
    } catch (e) {
      print('Error getting received content: $e');
      return [];
    }
  }

  // Helper method to calculate required tokens
  int _getRequiredTokens(int recipientCount, String contentType) {
    final baseTokens = contentType == 'photo' ? 1 : 2; // Photo: 1 token, Video: 2 tokens
    return baseTokens * recipientCount;
  }

  // Like/Unlike post
  Future<bool> toggleLike(String postId, String userId) async {
    try {
      // Check if already liked
      final existingLike = await _client
          .from('post_likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingLike != null) {
        // Unlike
        await _client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', userId);

        // Decrement likes count
        await _client.rpc('decrement_likes_count', params: {'post_id': postId});
      } else {
        // Like
        await _client.from('post_likes').insert({
          'post_id': postId,
          'user_id': userId,
        });

        // Increment likes count
        await _client.rpc('increment_likes_count', params: {'post_id': postId});
      }

      return true;
    } catch (e) {
      print('Error toggling like: $e');
      return false;
    }
  }
}