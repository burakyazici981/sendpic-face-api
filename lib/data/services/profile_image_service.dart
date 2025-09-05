import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class ProfileImageService {
  static final ProfileImageService _instance = ProfileImageService._internal();
  factory ProfileImageService() => _instance;
  ProfileImageService._internal();

  SupabaseClient get _client => SupabaseConfig.client;
  final ImagePicker _picker = ImagePicker();
  
  static const String _bucketName = 'profiles';
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Validate file size
        final fileSize = await image.length();
        if (fileSize > _maxFileSizeBytes) {
          throw Exception('File size too large. Maximum size is 5MB.');
        }
        
        // Validate file extension
        final extension = image.path.split('.').last.toLowerCase();
        if (!_allowedExtensions.contains(extension)) {
          throw Exception('Invalid file type. Only JPG, PNG, and WebP are allowed.');
        }
      }
      
      return image;
    } catch (e) {
      print('Error picking image: $e');
      rethrow;
    }
  }

  // Pick image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Validate file size
        final fileSize = await image.length();
        if (fileSize > _maxFileSizeBytes) {
          throw Exception('File size too large. Maximum size is 5MB.');
        }
      }
      
      return image;
    } catch (e) {
      print('Error taking photo: $e');
      rethrow;
    }
  }

  // Upload profile image to Supabase Storage
  Future<String?> uploadProfileImage({
    required String userId,
    required XFile imageFile,
  }) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'profile_${userId}_$timestamp.$extension';
      
      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await imageFile.readAsBytes();
      } else {
        imageBytes = await File(imageFile.path).readAsBytes();
      }
      
      // Delete old profile image if exists
      await _deleteOldProfileImage(userId);
      
      // Upload new image
      final response = await _client.storage
          .from(_bucketName)
          .uploadBinary(
            fileName,
            imageBytes,
            fileOptions: FileOptions(
              contentType: 'image/$extension',
              upsert: true,
            ),
          );
      
      if (response.isNotEmpty) {
        // Get public URL
        final publicUrl = _client.storage
            .from(_bucketName)
            .getPublicUrl(fileName);
        
        // Update user profile with new image URL
        await _updateUserProfileImage(userId, publicUrl);
        
        return publicUrl;
      }
      
      return null;
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }

  // Delete old profile image
  Future<void> _deleteOldProfileImage(String userId) async {
    try {
      // Get current user profile to find old image
      final userResponse = await _client
          .from('users')
          .select('profile_image_url')
          .eq('id', userId)
          .single();
      
      final oldImageUrl = userResponse['profile_image_url'] as String?;
      
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        // Extract filename from URL
        final uri = Uri.parse(oldImageUrl);
        final fileName = uri.pathSegments.last;
        
        // Delete from storage
        await _client.storage
            .from(_bucketName)
            .remove([fileName]);
      }
    } catch (e) {
      print('Error deleting old profile image: $e');
      // Don't throw error, just log it
    }
  }

  // Update user profile with new image URL
  Future<void> _updateUserProfileImage(String userId, String imageUrl) async {
    try {
      await _client
          .from('users')
          .update({'profile_image_url': imageUrl})
          .eq('id', userId);
    } catch (e) {
      print('Error updating user profile image: $e');
      rethrow;
    }
  }

  // Delete profile image
  Future<bool> deleteProfileImage(String userId) async {
    try {
      // Delete from storage
      await _deleteOldProfileImage(userId);
      
      // Remove URL from user profile
      await _client
          .from('users')
          .update({'profile_image_url': null})
          .eq('id', userId);
      
      return true;
    } catch (e) {
      print('Error deleting profile image: $e');
      return false;
    }
  }

  // Get profile image URL
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('profile_image_url')
          .eq('id', userId)
          .single();
      
      return response['profile_image_url'] as String?;
    } catch (e) {
      print('Error getting profile image URL: $e');
      return null;
    }
  }

  // Check if user has profile image
  Future<bool> hasProfileImage(String userId) async {
    try {
      final imageUrl = await getProfileImageUrl(userId);
      return imageUrl != null && imageUrl.isNotEmpty;
    } catch (e) {
      print('Error checking profile image: $e');
      return false;
    }
  }

  // Get profile image file info
  Future<Map<String, dynamic>?> getProfileImageInfo(String userId) async {
    try {
      final imageUrl = await getProfileImageUrl(userId);
      
      if (imageUrl == null || imageUrl.isEmpty) {
        return null;
      }
      
      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;
      
      // Get file info from storage
      final files = await _client.storage
          .from(_bucketName)
          .list(path: '', searchOptions: const SearchOptions(
            limit: 1000,
          ));
      
      final fileInfo = files.firstWhere(
        (file) => file.name == fileName,
        orElse: () => throw Exception('File not found'),
      );
      
      return {
        'name': fileInfo.name,
        'size': fileInfo.metadata?['size'],
        'last_modified': fileInfo.updatedAt,
        'url': imageUrl,
      };
    } catch (e) {
      print('Error getting profile image info: $e');
      return null;
    }
  }

  // Validate image file
  static bool isValidImageFile(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return _allowedExtensions.contains(extension);
  }

  // Get max file size in MB
  static double get maxFileSizeMB => _maxFileSizeBytes / (1024 * 1024);

  // Get allowed extensions
  static List<String> get allowedExtensions => List.from(_allowedExtensions);
}