import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/content_model.dart';
import '../models/token_model.dart';
import 'database_helper.dart';
import 'local_storage_service.dart';

class SQLiteService {
  static final SQLiteService _instance = SQLiteService._internal();
  factory SQLiteService() => _instance;
  SQLiteService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LocalStorageService _storageService = LocalStorageService();
  final Uuid _uuid = const Uuid();

  // Current user session
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Auth Methods
  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    String? gender,
    int? age,
  }) async {
    try {
      // Check if user already exists
      final existingUsers = await _dbHelper.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );

      if (existingUsers.isNotEmpty) {
        throw Exception('Bu email adresi zaten kayıtlı');
      }

      // Hash password
      final passwordHash = _hashPassword(password);
      final userId = _uuid.v4();
      final now = DateTime.now();

      final userData = {
        'id': userId,
        'email': email,
        'name': name,
        'password_hash': passwordHash,
        'gender': gender,
        'age': age,
        'is_verified': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await _dbHelper.insert('users', userData);

      // Give initial tokens
      await _addTokens(
        userId: userId,
        amount: 50, // Initial tokens
        transactionType: TransactionType.earned,
      );

      final user = UserModel.fromJson(userData);
      _currentUser = user;
      return user;
    } catch (e) {
      print('Error signing up: $e');
      return null;
    }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final users = await _dbHelper.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );

      if (users.isEmpty) {
        throw Exception('Kullanıcı bulunamadı');
      }

      final userData = users.first;
      final storedHash = userData['password_hash'] as String;

      if (!_verifyPassword(password, storedHash)) {
        throw Exception('Şifre hatalı');
      }

      final user = UserModel.fromJson(userData);
      _currentUser = user;
      return user;
    } catch (e) {
      print('Error signing in: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
  }

  // User Profile Methods
  Future<UserModel?> getUserProfile(String userId) async {
    try {
      final users = await _dbHelper.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (users.isNotEmpty) {
        return UserModel.fromJson(users.first);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<bool> updateUserProfile(UserModel user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      final result = await _dbHelper.update(
        'users',
        updatedUser.toJson(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
      
      if (_currentUser?.id == user.id) {
        _currentUser = updatedUser;
      }
      
      return result > 0;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // Content Methods
  Future<String?> uploadMedia(File file, String bucket) async {
    try {
      return await _storageService.saveFile(file, bucket);
    } catch (e) {
      print('Error uploading media: $e');
      return null;
    }
  }

  Future<ContentModel?> createContent({
    required String senderId,
    required String mediaUrl,
    required MediaType mediaType,
  }) async {
    try {
      final contentId = _uuid.v4();
      final now = DateTime.now();

      final contentData = {
        'id': contentId,
        'sender_id': senderId,
        'media_url': mediaUrl,
        'media_type': mediaType.name,
        'created_at': now.toIso8601String(),
      };

      await _dbHelper.insert('contents', contentData);
      return ContentModel.fromJson(contentData);
    } catch (e) {
      print('Error creating content: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> sendRandomContent({
    required String contentId,
    required int recipientCount,
    required String senderId,
  }) async {
    try {
      return await _dbHelper.transaction((txn) async {
        // Check user token balance
        final tokenBalance = await getUserTokenBalance(senderId);
        final requiredTokens = _getRequiredTokens(recipientCount);

        if (tokenBalance < requiredTokens) {
          return {
            'success': false,
            'error': 'Insufficient tokens',
          };
        }

        // Get random verified users (excluding sender)
        final users = await _dbHelper.rawQuery('''
          SELECT id FROM users 
          WHERE id != ? AND is_verified = 1 
          ORDER BY RANDOM() 
          LIMIT ?
        ''', [senderId, recipientCount]);

        if (users.isEmpty) {
          return {
            'success': false,
            'error': 'No recipients found',
          };
        }

        // Insert content recipients
        final now = DateTime.now();
        for (final user in users) {
          await txn.insert('content_recipients', {
            'id': _uuid.v4(),
            'content_id': contentId,
            'recipient_id': user['id'],
            'received_at': now.toIso8601String(),
          });
        }

        // Deduct tokens
        await txn.insert('tokens', {
          'id': _uuid.v4(),
          'user_id': senderId,
          'amount': -requiredTokens,
          'transaction_type': TransactionType.spent.name,
          'created_at': now.toIso8601String(),
        });

        final newBalance = tokenBalance - requiredTokens;

        return {
          'success': true,
          'sent_count': users.length,
          'remaining_tokens': newBalance,
        };
      });
    } catch (e) {
      print('Error sending random content: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<List<ContentModel>> getReceivedContent(String userId) async {
    try {
      final results = await _dbHelper.rawQuery('''
        SELECT c.* FROM contents c
        INNER JOIN content_recipients cr ON c.id = cr.content_id
        WHERE cr.recipient_id = ?
        ORDER BY cr.received_at DESC
      ''', [userId]);

      return results.map((item) => ContentModel.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching received content: $e');
      return [];
    }
  }

  // Token Methods
  Future<int> getUserTokenBalance(String userId) async {
    try {
      final results = await _dbHelper.rawQuery('''
        SELECT SUM(amount) as total FROM tokens WHERE user_id = ?
      ''', [userId]);

      if (results.isNotEmpty && results.first['total'] != null) {
        return results.first['total'] as int;
      }
      return 0;
    } catch (e) {
      print('Error fetching token balance: $e');
      return 0;
    }
  }

  Future<List<TokenModel>> getUserTokenHistory(String userId) async {
    try {
      final results = await _dbHelper.query(
        'tokens',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );

      return results.map((item) => TokenModel.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching token history: $e');
      return [];
    }
  }

  Future<bool> _addTokens({
    required String userId,
    required int amount,
    required TransactionType transactionType,
  }) async {
    try {
      await _dbHelper.insert('tokens', {
        'id': _uuid.v4(),
        'user_id': userId,
        'amount': amount,
        'transaction_type': transactionType.name,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error adding tokens: $e');
      return false;
    }
  }

  Future<bool> addTokens({
    required String userId,
    required int amount,
    required TransactionType transactionType,
  }) async {
    return await _addTokens(
      userId: userId,
      amount: amount,
      transactionType: transactionType,
    );
  }

  // Friend System Methods
  Future<bool> sendFriendRequest(String requesterId, String addresseeId) async {
    try {
      // Check if friendship already exists
      final existing = await _dbHelper.query(
        'friendships',
        where: '(requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?)',
        whereArgs: [requesterId, addresseeId, addresseeId, requesterId],
      );

      if (existing.isNotEmpty) {
        return false; // Friendship already exists
      }

      final now = DateTime.now();
      await _dbHelper.insert('friendships', {
        'id': _uuid.v4(),
        'requester_id': requesterId,
        'addressee_id': addresseeId,
        'status': 'pending',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error sending friend request: $e');
      return false;
    }
  }

  Future<bool> acceptFriendRequest(String friendshipId) async {
    try {
      final result = await _dbHelper.update(
        'friendships',
        {
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [friendshipId],
      );
      return result > 0;
    } catch (e) {
      print('Error accepting friend request: $e');
      return false;
    }
  }

  // Messaging Methods
  Future<bool> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? mediaUrl,
  }) async {
    try {
      await _dbHelper.insert('messages', {
        'id': _uuid.v4(),
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'media_url': mediaUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String userId, String friendId) async {
    try {
      return await _dbHelper.rawQuery('''
        SELECT * FROM messages
        WHERE (sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)
        ORDER BY created_at ASC
      ''', [userId, friendId, friendId, userId]);
    } catch (e) {
      print('Error fetching messages: $e');
      return [];
    }
  }

  // Content interaction methods
  Future<bool> likeContent(String contentId, String userId) async {
    try {
      // Update content_recipients table to mark as liked
      final result = await _dbHelper.update(
        'content_recipients',
        {'is_liked': 1},
        where: 'content_id = ? AND recipient_id = ?',
        whereArgs: [contentId, userId],
      );
      return result > 0;
    } catch (e) {
      print('Error liking content: $e');
      return false;
    }
  }

  // Upload image to local storage
  Future<String?> uploadImage(File imageFile) async {
    try {
      // For local storage, we'll just return the file path
      // In a real app, you might want to copy to a specific directory
      return imageFile.path;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Upload video to local storage
  Future<String?> uploadVideo(File videoFile) async {
    try {
      // For local storage, we'll just return the file path
      // In a real app, you might want to copy to a specific directory
      return videoFile.path;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  // Helper methods
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyPassword(String password, String hash) {
    return _hashPassword(password) == hash;
  }

  int _getRequiredTokens(int recipientCount) {
    switch (recipientCount) {
      case 6:
        return 1;
      case 10:
        return 2;
      case 100:
        return 10;
      case 1000:
        return 50;
      default:
        return 1;
    }
  }
}
