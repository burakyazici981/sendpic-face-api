import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/supabase_config.dart';

class SupabaseStorageService {
  static final SupabaseStorageService _instance = SupabaseStorageService._internal();
  factory SupabaseStorageService() => _instance;
  SupabaseStorageService._internal();

  SupabaseClient get _client => SupabaseConfig.client;
  final Uuid _uuid = const Uuid();

  // Storage bucket names
  static const String photosBucket = 'photos';
  static const String videosBucket = 'videos';
  static const String profilesBucket = 'profiles';
  static const String tempBucket = 'temp';

  /// Upload image to Supabase Storage
  Future<String?> uploadImage({
    required Uint8List imageBytes,
    required String userId,
    String? fileName,
    String bucket = photosBucket,
    bool isTemporary = false,
  }) async {
    try {
      final fileExtension = fileName?.split('.').last ?? 'jpg';
      final uniqueFileName = fileName ?? '${_uuid.v4()}.$fileExtension';
      final filePath = isTemporary 
          ? 'temp/$userId/$uniqueFileName'
          : '$userId/$uniqueFileName';

      final response = await _client.storage
          .from(bucket)
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      if (response.isNotEmpty) {
        // Get public URL
        final publicUrl = _client.storage
            .from(bucket)
            .getPublicUrl(filePath);
        
        return publicUrl;
      }
      
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Upload image from file path
  Future<String?> uploadImageFromFile({
    required String filePath,
    required String userId,
    String? customFileName,
    String bucket = photosBucket,
    bool isTemporary = false,
  }) async {
    try {
      if (kIsWeb) {
        throw UnsupportedError('File upload from path not supported on web');
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File does not exist', filePath);
      }
      
      final imageBytes = await file.readAsBytes();
      final fileName = customFileName ?? file.path.split('/').last;
      
      return await uploadImage(
        imageBytes: imageBytes,
        userId: userId,
        fileName: fileName,
        bucket: bucket,
        isTemporary: isTemporary,
      );
    } catch (e) {
      print('Error uploading image from file: $e');
      return null;
    }
  }

  /// Upload video to Supabase Storage
  Future<String?> uploadVideo({
    required Uint8List videoBytes,
    required String userId,
    String? fileName,
    bool isTemporary = false,
  }) async {
    try {
      final fileExtension = fileName?.split('.').last ?? 'mp4';
      final uniqueFileName = fileName ?? '${_uuid.v4()}.$fileExtension';
      final filePath = isTemporary 
          ? 'temp/$userId/$uniqueFileName'
          : '$userId/$uniqueFileName';

      final response = await _client.storage
          .from(videosBucket)
          .uploadBinary(
            filePath,
            videoBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      if (response.isNotEmpty) {
        final publicUrl = _client.storage
            .from(videosBucket)
            .getPublicUrl(filePath);
        
        return publicUrl;
      }
      
      return null;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  /// Upload profile picture
  Future<String?> uploadProfilePicture({
    required Uint8List imageBytes,
    required String userId,
    String? fileName,
  }) async {
    try {
      // Delete existing profile picture first
      await deleteProfilePicture(userId);
      
      final fileExtension = fileName?.split('.').last ?? 'jpg';
      final profileFileName = 'profile_$userId.$fileExtension';
      
      return await uploadImage(
        imageBytes: imageBytes,
        userId: userId,
        fileName: profileFileName,
        bucket: profilesBucket,
        isTemporary: false,
      );
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }

  /// Download image as bytes
  Future<Uint8List?> downloadImage(String url) async {
    try {
      // Extract bucket and path from URL
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length < 3) {
        throw ArgumentError('Invalid storage URL format');
      }
      
      final bucket = pathSegments[pathSegments.length - 3];
      final filePath = pathSegments.sublist(pathSegments.length - 2).join('/');
      
      final response = await _client.storage
          .from(bucket)
          .download(filePath);
      
      return response;
    } catch (e) {
      print('Error downloading image: $e');
      return null;
    }
  }

  /// Get signed URL for temporary access
  Future<String?> getSignedUrl({
    required String bucket,
    required String filePath,
    int expiresInSeconds = 3600, // 1 hour default
  }) async {
    try {
      final signedUrl = await _client.storage
          .from(bucket)
          .createSignedUrl(filePath, expiresInSeconds);
      
      return signedUrl;
    } catch (e) {
      print('Error creating signed URL: $e');
      return null;
    }
  }

  /// Delete file from storage
  Future<bool> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await _client.storage
          .from(bucket)
          .remove([filePath]);
      
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// Delete profile picture
  Future<bool> deleteProfilePicture(String userId) async {
    try {
      // List all files in user's profile folder
      final files = await _client.storage
          .from(profilesBucket)
          .list(path: userId);
      
      if (files.isNotEmpty) {
        final filePaths = files.map((file) => '$userId/${file.name}').toList();
        await _client.storage
            .from(profilesBucket)
            .remove(filePaths);
      }
      
      return true;
    } catch (e) {
      print('Error deleting profile picture: $e');
      return false;
    }
  }

  /// Delete all user files
  Future<bool> deleteAllUserFiles(String userId) async {
    try {
      final buckets = [photosBucket, videosBucket, profilesBucket, tempBucket];
      
      for (final bucket in buckets) {
        try {
          final files = await _client.storage
              .from(bucket)
              .list(path: userId);
          
          if (files.isNotEmpty) {
            final filePaths = files.map((file) => '$userId/${file.name}').toList();
            await _client.storage
                .from(bucket)
                .remove(filePaths);
          }
        } catch (e) {
          print('Error deleting files from bucket $bucket: $e');
        }
      }
      
      return true;
    } catch (e) {
      print('Error deleting all user files: $e');
      return false;
    }
  }

  /// Clean up temporary files (older than specified duration)
  Future<void> cleanupTempFiles({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    try {
      final tempFiles = await _client.storage
          .from(tempBucket)
          .list();
      
      final cutoffTime = DateTime.now().subtract(maxAge);
      final filesToDelete = <String>[];
      
      for (final file in tempFiles) {
        if (file.updatedAt != null && DateTime.parse(file.updatedAt!).isBefore(cutoffTime)) {
          filesToDelete.add(file.name);
        }
      }
      
      if (filesToDelete.isNotEmpty) {
        await _client.storage
            .from(tempBucket)
            .remove(filesToDelete);
        
        print('Cleaned up ${filesToDelete.length} temporary files');
      }
    } catch (e) {
      print('Error cleaning up temp files: $e');
    }
  }

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats(String userId) async {
    try {
      final buckets = [photosBucket, videosBucket, profilesBucket];
      final stats = <String, dynamic>{
        'totalFiles': 0,
        'totalSize': 0,
        'bucketStats': <String, dynamic>{},
      };
      
      for (final bucket in buckets) {
        try {
          final files = await _client.storage
              .from(bucket)
              .list(path: userId);
          
          final bucketSize = files.fold<int>(
            0, 
            (sum, file) => sum + (file.metadata?['size'] as int? ?? 0)
          );
          
          stats['bucketStats'][bucket] = {
            'fileCount': files.length,
            'totalSize': bucketSize,
          };
          
          stats['totalFiles'] += files.length;
          stats['totalSize'] += bucketSize;
        } catch (e) {
          print('Error getting stats for bucket $bucket: $e');
        }
      }
      
      return stats;
    } catch (e) {
      print('Error getting storage stats: $e');
      return {
        'totalFiles': 0,
        'totalSize': 0,
        'bucketStats': <String, dynamic>{},
      };
    }
  }

  /// Check if file exists
  Future<bool> fileExists({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await _client.storage
          .from(bucket)
          .download(filePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file info
  Future<Map<String, dynamic>?> getFileInfo({
    required String bucket,
    required String filePath,
  }) async {
    try {
      final files = await _client.storage
          .from(bucket)
          .list(path: filePath.split('/').first);
      
      final fileName = filePath.split('/').last;
      final file = files.firstWhere(
        (f) => f.name == fileName,
        orElse: () => throw StateError('File not found'),
      );
      
      return {
        'name': file.name,
        'size': file.metadata?['size'],
        'lastModified': file.updatedAt,
        'contentType': file.metadata?['mimetype'],
      };
    } catch (e) {
      print('Error getting file info: $e');
      return null;
    }
  }
}