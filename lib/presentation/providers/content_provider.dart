import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/content_model.dart';
import '../../data/models/content_recipient_model.dart';
import '../../data/models/friendship_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/token_model.dart';
import '../../data/services/sqlite_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/supabase_posts_service.dart';
import '../../data/services/supabase_auth_service.dart';
import '../../data/services/backend_api_service.dart';

enum ContentStatus { initial, loading, loaded, sending, error }

class ContentProvider with ChangeNotifier {
  final SQLiteService _sqliteService = SQLiteService();
  final AuthService _authService = AuthService();
  final SupabasePostsService _supabasePostsService = SupabasePostsService();
  final SupabaseAuthService _supabaseAuthService = SupabaseAuthService();
  final BackendApiService _backendApi = BackendApiService();
  
  ContentStatus _status = ContentStatus.initial;
  String? _errorMessage;
  List<ContentModel> _receivedContent = [];
  List<ContentRecipientModel> _unviewedContent = [];
  List<FriendshipModel> _friendships = [];
  List<MessageModel> _messages = [];
  int _tokenBalance = 0;
  List<TokenModel> _tokenHistory = [];
  bool _useSupabase = true; // Primary: Supabase, Fallback: SQLite

  // Getters
  ContentStatus get status => _status;
  String? get errorMessage => _errorMessage;
  List<ContentModel> get receivedContent => _receivedContent;
  List<ContentRecipientModel> get unviewedContent => _unviewedContent;
  List<FriendshipModel> get friendships => _friendships;
  List<MessageModel> get messages => _messages;
  int get tokenBalance => _tokenBalance;
  List<TokenModel> get tokenHistory => _tokenHistory;

  // Load user's received content
  Future<void> loadReceivedContent(String userId) async {
    _status = ContentStatus.loading;
    notifyListeners();

    try {
      if (_useSupabase) {
        final contentRecipients = await _supabasePostsService.getReceivedContent(userId);
        // Convert ContentRecipientModel to ContentModel for compatibility
        _receivedContent = contentRecipients.map((recipient) {
          final postInfo = recipient.postInfo;
          return ContentModel(
            id: recipient.contentId,
            senderId: recipient.senderId,
            mediaUrl: recipient.mediaUrl,
            mediaType: postInfo?['content_type'] == 'photo' ? MediaType.image : MediaType.video,
            caption: postInfo?['caption'],
            thumbnailUrl: postInfo?['thumbnail_url'],
            isPublic: postInfo?['is_public'] ?? true,
            likesCount: postInfo?['likes_count'] ?? 0,
            commentsCount: postInfo?['comments_count'] ?? 0,
            createdAt: recipient.receivedAt,
            updatedAt: recipient.receivedAt,
            senderInfo: postInfo?['users'],
          );
        }).toList();
      } else {
        _receivedContent = await _sqliteService.getReceivedContent(userId);
      }
      
      _status = ContentStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      _status = ContentStatus.error;
      _errorMessage = 'İçerikler yüklenemedi: $e';
    }
    
    notifyListeners();
  }

  // Load user's token balance
  Future<void> loadTokenBalance(String userId) async {
    try {
      // Try backend API first
      if (_backendApi.isLoggedIn) {
        final result = await _backendApi.getUserTokens();
        if (result != null && result['success'] == true) {
          final tokens = result['tokens'];
          _tokenBalance = (tokens['photo_tokens'] ?? 0) + (tokens['video_tokens'] ?? 0);
          notifyListeners();
          return;
        }
      }
      
      // Fallback to Supabase
      if (_useSupabase) {
        final tokens = await _supabaseAuthService.getUserTokens();
        _tokenBalance = (tokens['photo_tokens'] ?? 0) + (tokens['video_tokens'] ?? 0);
      } else {
        _tokenBalance = await _sqliteService.getUserTokenBalance(userId);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Jeton bakiyesi yüklenemedi: $e';
      notifyListeners();
    }
  }

  // Load user's token history
  Future<void> loadTokenHistory(String userId) async {
    try {
      if (_useSupabase) {
        // For now, we'll use an empty list as token history is not implemented in Supabase service yet
        // This would require querying the token_transactions table
        _tokenHistory = [];
      } else {
        _tokenHistory = await _sqliteService.getUserTokenHistory(userId);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Jeton geçmişi yüklenemedi: $e';
      notifyListeners();
    }
  }

  // Send content to random users
  Future<bool> sendContent({
    required File mediaFile,
    required MediaType mediaType,
    required int recipientCount,
    required String senderId,
    String? caption,
  }) async {
    // Web platformunda içerik gönderme desteği yok
    if (kIsWeb) {
      _errorMessage = 'Web platformunda içerik gönderme özelliği desteklenmemektedir. Lütfen mobil uygulamayı kullanın.';
      _status = ContentStatus.error;
      notifyListeners();
      return false;
    }

    _status = ContentStatus.sending;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if user has enough tokens
      final requiredTokens = _getRequiredTokens(recipientCount, mediaType);
      if (_tokenBalance < requiredTokens) {
        _status = ContentStatus.error;
        _errorMessage = 'Yeterli jetonunuz yok. Gerekli: $requiredTokens, Mevcut: $_tokenBalance';
        notifyListeners();
        return false;
      }

      if (_useSupabase) {
        // First upload media to storage
        final mediaUrl = await _uploadMediaToStorage(mediaFile, senderId, mediaType);
        
        if (mediaUrl == null) {
          _status = ContentStatus.error;
          _errorMessage = 'Medya yüklenemedi';
          notifyListeners();
          return false;
        }
        
        // Create post using Supabase
        final contentId = await _supabasePostsService.createPost(
          userId: senderId,
          content: caption,
          mediaUrl: mediaUrl,
          mediaType: mediaType == MediaType.image ? 'photo' : 'video',
          isPublic: false, // Random content is not public
        );

        if (contentId == null) {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik oluşturulamadı';
          notifyListeners();
          return false;
        }

        // Send to random users
        final result = await _supabasePostsService.sendToRandomUsers(
          postId: contentId,
          count: recipientCount,
        );
        
        if (result) {
          // Update token balance
          await loadTokenBalance(senderId);
          
          _status = ContentStatus.loaded;
          _errorMessage = null;
          notifyListeners();
          return true;
        } else {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik gönderilemedi';
          notifyListeners();
          return false;
        }
      } else {
        // Fallback to SQLite
        final mediaUrl = await _sqliteService.uploadMedia(
          mediaFile,
          AppConstants.mediaBucket,
        );

        if (mediaUrl == null) {
          _status = ContentStatus.error;
          _errorMessage = 'Medya yüklenemedi';
          notifyListeners();
          return false;
        }

        final content = await _sqliteService.createContent(
          senderId: senderId,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        );

        if (content == null) {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik oluşturulamadı';
          notifyListeners();
          return false;
        }

        final result = await _sqliteService.sendRandomContent(
          contentId: content.id,
          recipientCount: recipientCount,
          senderId: senderId,
        );

        if (result != null && result['success'] == true) {
          _tokenBalance = result['remaining_tokens'] as int;
          _status = ContentStatus.loaded;
          _errorMessage = null;
          notifyListeners();
          return true;
        } else {
          _status = ContentStatus.error;
          _errorMessage = result?['error'] ?? 'İçerik gönderilemedi';
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      _status = ContentStatus.error;
      _errorMessage = 'İçerik gönderilirken hata oluştu: $e';
      notifyListeners();
      return false;
    }
  }

  // Send random video
  Future<bool> sendRandomVideo(File videoFile, String senderId) async {
    _status = ContentStatus.sending;
    notifyListeners();

    try {
      if (_useSupabase) {
        // Upload video to Supabase storage
        final videoUrl = await _supabasePostsService.uploadVideo(videoFile);
        
        if (videoUrl == null) {
          _status = ContentStatus.error;
          _errorMessage = 'Video yüklenemedi';
          notifyListeners();
          return false;
        }

        // Create content
        final content = await _supabasePostsService.createContent(
          senderId: senderId,
          mediaUrl: videoUrl,
          mediaType: 'video',
        );

        if (content == null) {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik oluşturulamadı';
          notifyListeners();
          return false;
        }

        // Send to random user
        final success = await _supabasePostsService.sendRandomContent(
          contentId: content.id,
          senderId: senderId,
        );

        if (success) {
          _status = ContentStatus.loaded;
          _errorMessage = null;
          notifyListeners();
          return true;
        } else {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik gönderilemedi';
          notifyListeners();
          return false;
        }
      } else {
        // Fallback to SQLite
        final videoUrl = await _sqliteService.uploadVideo(videoFile);
        
        if (videoUrl == null) {
          _status = ContentStatus.error;
          _errorMessage = 'Video yüklenemedi';
          notifyListeners();
          return false;
        }

        final content = await _sqliteService.createContent(
          senderId: senderId,
          mediaUrl: videoUrl,
          mediaType: MediaType.video,
        );

        if (content == null) {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik oluşturulamadı';
          notifyListeners();
          return false;
        }

        final result = await _sqliteService.sendRandomContent(
          contentId: content.id,
          recipientCount: 1, // Send to 1 random user
          senderId: senderId,
        );

        if (result != null && result['success'] == true) {
          _tokenBalance = result['remaining_tokens'] as int;
          _status = ContentStatus.loaded;
          _errorMessage = null;
          notifyListeners();
          return true;
        } else {
          _status = ContentStatus.error;
          _errorMessage = result?['error'] ?? 'İçerik gönderilemedi';
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      _status = ContentStatus.error;
      _errorMessage = 'Video gönderilirken hata oluştu: $e';
      notifyListeners();
      return false;
    }
  }

  // Send random photo (simplified version)
  Future<bool> sendRandomPhoto(File imageFile, String senderId) async {
    _status = ContentStatus.sending;
    notifyListeners();

    try {
      if (_useSupabase) {
        // Upload image to Supabase storage
        final imageUrl = await _supabasePostsService.uploadImage(imageFile);
        
        if (imageUrl == null) {
          _status = ContentStatus.error;
          _errorMessage = 'Resim yüklenemedi';
          notifyListeners();
          return false;
        }

        // Create content
        final content = await _supabasePostsService.createContent(
          senderId: senderId,
          mediaUrl: imageUrl,
          mediaType: 'image',
        );

        if (content == null) {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik oluşturulamadı';
          notifyListeners();
          return false;
        }

        // Send to random user
        final success = await _supabasePostsService.sendRandomContent(
          contentId: content.id,
          senderId: senderId,
        );

        if (success) {
          _status = ContentStatus.loaded;
          _errorMessage = null;
          notifyListeners();
          return true;
        } else {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik gönderilemedi';
          notifyListeners();
          return false;
        }
      } else {
        // Fallback to SQLite
        final imageUrl = await _sqliteService.uploadImage(imageFile);
        
        if (imageUrl == null) {
          _status = ContentStatus.error;
          _errorMessage = 'Resim yüklenemedi';
          notifyListeners();
          return false;
        }

        final content = await _sqliteService.createContent(
          senderId: senderId,
          mediaUrl: imageUrl,
          mediaType: MediaType.image,
        );

        if (content == null) {
          _status = ContentStatus.error;
          _errorMessage = 'İçerik oluşturulamadı';
          notifyListeners();
          return false;
        }

        final result = await _sqliteService.sendRandomContent(
          contentId: content.id,
          recipientCount: 1, // Send to 1 random user
          senderId: senderId,
        );

        if (result != null && result['success'] == true) {
          _tokenBalance = result['remaining_tokens'] as int;
          _status = ContentStatus.loaded;
          _errorMessage = null;
          notifyListeners();
          return true;
        } else {
          _status = ContentStatus.error;
          _errorMessage = result?['error'] ?? 'İçerik gönderilemedi';
          notifyListeners();
          return false;
        }
      }
    } catch (e) {
      _status = ContentStatus.error;
      _errorMessage = 'Fotoğraf gönderilirken hata oluştu: $e';
      notifyListeners();
      return false;
    }
  }

  // Load unviewed content for discover screen
  Future<void> loadUnviewedContent(String userId) async {
    try {
      if (kIsWeb) {
        _unviewedContent = await _authService.getUserContent();
      } else {
        // Mobile implementation would go here
        _unviewedContent = [];
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Görülmemiş içerikler yüklenemedi: $e';
      notifyListeners();
    }
  }

  // Mark content as viewed (one-time view)
  Future<bool> markContentAsViewed(String contentId, String userId) async {
    try {
      bool success;
      if (kIsWeb) {
        success = true; // Simplified implementation
      } else {
        // Mobile implementation would go here
        success = false;
      }
      
      if (success) {
        // Remove from unviewed list
        _unviewedContent.removeWhere((content) => content.contentId == contentId);
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'İçerik görüntüleme kaydedilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  // Like content
  Future<bool> likeContent(String contentId, String userId) async {
    try {
      bool success;
      if (kIsWeb) {
        success = true; // Simplified implementation
      } else {
        // Mobile implementation would go here
        success = await _sqliteService.likeContent(contentId, userId);
      }
      
      if (success) {
        // Update the content in unviewed list
        final index = _unviewedContent.indexWhere((content) => content.contentId == contentId);
        if (index != -1) {
          _unviewedContent[index] = _unviewedContent[index].copyWith(isLiked: true);
          notifyListeners();
        }
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Beğeni işlemi başarısız: $e';
      notifyListeners();
      return false;
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String requesterId, String addresseeId) async {
    try {
      bool success;
      if (kIsWeb) {
        success = true; // Simplified implementation
      } else {
        success = await _sqliteService.sendFriendRequest(requesterId, addresseeId);
      }
      
      if (success) {
        // Refresh friendships
        await loadFriendships(requesterId);
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Arkadaş talebi gönderilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  // Load user's friendships
  Future<void> loadFriendships(String userId) async {
    try {
      if (kIsWeb) {
        _friendships = []; // Simplified implementation
      } else {
        // Mobile implementation would go here
        _friendships = [];
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Arkadaşlıklar yüklenemedi: $e';
      notifyListeners();
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String friendshipId, String userId) async {
    try {
      bool success;
      if (kIsWeb) {
        success = true; // Simplified implementation
      } else {
        // Mobile implementation would go here
        success = false;
      }
      
      if (success) {
        // Update local friendship status
        final index = _friendships.indexWhere((f) => f.id == friendshipId);
        if (index != -1) {
          _friendships[index] = _friendships[index].accept();
          notifyListeners();
        }
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Arkadaş talebi kabul edilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  // Reject friend request
  Future<bool> rejectFriendRequest(String friendshipId, String userId) async {
    try {
      bool success;
      if (kIsWeb) {
        success = true; // Simplified implementation
      } else {
        // Mobile implementation would go here
        success = false;
      }
      
      if (success) {
        // Update local friendship status
        final index = _friendships.indexWhere((f) => f.id == friendshipId);
        if (index != -1) {
          _friendships[index] = _friendships[index].reject();
          notifyListeners();
        }
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Arkadaş talebi reddedilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  // Purchase tokens
  Future<bool> purchaseTokens({
    required String userId,
    required int amount,
  }) async {
    try {
      final success = await _sqliteService.addTokens(
        userId: userId,
        amount: amount,
        transactionType: TransactionType.purchased,
      );

      if (success) {
        _tokenBalance += amount;
        await loadTokenHistory(userId); // Refresh history
        notifyListeners();
      }

      return success;
    } catch (e) {
      _errorMessage = 'Jeton satın alınamadı: $e';
      notifyListeners();
      return false;
    }
  }

  // Load messages for a specific conversation
  Future<void> loadMessages(String userId, String otherUserId) async {
    try {
      if (kIsWeb) {
        _messages = []; // Simplified implementation
      } else {
        // Mobile implementation would go here
        _messages = [];
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Mesajlar yüklenemedi: $e';
      notifyListeners();
    }
  }

  // Send a message
  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? mediaUrl,
  }) async {
    try {
      bool success;
      if (kIsWeb) {
        success = true; // Simplified implementation
        /*success = await _webAuthService.sendMessage(
          senderId: senderId,
          receiverId: receiverId,
          content: content,
          mediaUrl: mediaUrl,
        );*/
      } else {
        // Mobile implementation would go here
        success = false;
      }
      
      if (success) {
        // Refresh messages
        await loadMessages(senderId, receiverId);
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Mesaj gönderilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  // Mark message as read
  Future<bool> markMessageAsRead(String messageId, String userId) async {
    try {
      bool success;
      if (kIsWeb) {
        success = true; // Simplified implementation
      } else {
        // Mobile implementation would go here
        success = false;
      }
      
      if (success) {
        // Update local message status
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = _messages[index].markAsRead();
          notifyListeners();
        }
      }
      
      return success;
    } catch (e) {
      _errorMessage = 'Mesaj okundu olarak işaretlenemedi: $e';
      notifyListeners();
      return false;
    }
  }

  // Get accepted friends (for messaging)
  List<FriendshipModel> get acceptedFriends {
    return _friendships.where((f) => f.status == FriendshipStatus.accepted).toList();
  }

  // Get pending friend requests
  List<FriendshipModel> get pendingRequests {
    return _friendships.where((f) => f.status == FriendshipStatus.pending).toList();
  }

  // Refresh all data
  Future<void> refreshData(String userId) async {
    await Future.wait([
      loadReceivedContent(userId),
      loadUnviewedContent(userId),
      loadFriendships(userId),
      loadTokenBalance(userId),
      loadTokenHistory(userId),
    ]);
  }

  // Helper methods
  int _getRequiredTokens(int recipientCount, [MediaType? mediaType]) {
    final baseTokens = mediaType == MediaType.video ? 2 : 1; // Video costs more
    
    switch (recipientCount) {
      case 6:
        return AppConstants.tokensFor6Recipients * baseTokens;
      case 10:
        return AppConstants.tokensFor10Recipients * baseTokens;
      case 100:
        return AppConstants.tokensFor100Recipients * baseTokens;
      case 1000:
        return AppConstants.tokensFor1000Recipients * baseTokens;
      default:
        return baseTokens;
    }
  }

  bool canSendToRecipients(int recipientCount, [MediaType? mediaType]) {
    final requiredTokens = _getRequiredTokens(recipientCount, mediaType);
    return _tokenBalance >= requiredTokens;
  }

  String getTokenRequirementText(int recipientCount, [MediaType? mediaType]) {
    final requiredTokens = _getRequiredTokens(recipientCount, mediaType);
    final mediaText = mediaType == MediaType.video ? ' (Video)' : ' (Foto)';
    return '$recipientCount kişi$mediaText - $requiredTokens jeton';
  }

  // Toggle between Supabase and SQLite (for testing/fallback)
  void toggleDataSource() {
    _useSupabase = !_useSupabase;
    notifyListeners();
  }
  
  // Helper method to upload media to storage
  Future<String?> _uploadMediaToStorage(File mediaFile, String userId, MediaType mediaType) async {
    try {
      // This is a simplified implementation
      // In a real app, you would use SupabaseStorageService
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${mediaFile.path.split('/').last}';
      final bucket = mediaType == MediaType.image ? 'photos' : 'videos';
      
      // For now, return a mock URL
      // In production, this would upload to Supabase Storage
      return 'https://example.com/$bucket/$fileName';
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  bool get useSupabase => _useSupabase;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearContent() {
    _receivedContent.clear();
    notifyListeners();
  }
}
