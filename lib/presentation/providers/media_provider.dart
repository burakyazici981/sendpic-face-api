import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import '../../data/services/supabase_storage_service.dart';
import '../../data/services/supabase_auth_service.dart';
import '../../data/services/supabase_posts_service.dart';

enum MediaType { photo, video }
enum MediaSource { camera, gallery }
enum MediaStatus { idle, picking, uploading, processing, completed, error }

class MediaProvider extends ChangeNotifier {
  final SupabaseStorageService _storageService = SupabaseStorageService();
  final SupabaseAuthService _authService = SupabaseAuthService();
  final SupabasePostsService _postsService = SupabasePostsService();
  final ImagePicker _picker = ImagePicker();

  MediaStatus _status = MediaStatus.idle;
  String? _errorMessage;
  String? _currentMediaUrl;
  MediaType? _currentMediaType;
  double _uploadProgress = 0.0;
  
  // Getters
  MediaStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentMediaUrl => _currentMediaUrl;
  MediaType? get currentMediaType => _currentMediaType;
  double get uploadProgress => _uploadProgress;
  bool get isLoading => _status == MediaStatus.picking || 
                       _status == MediaStatus.uploading || 
                       _status == MediaStatus.processing;

  /// Pick image from gallery
  Future<String?> pickImageFromGallery() async {
    try {
      _setStatus(MediaStatus.picking);
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _processAndUploadImage(image);
      }
      
      _setStatus(MediaStatus.idle);
      return null;
    } catch (e) {
      _setError('Failed to pick image from gallery: $e');
      return null;
    }
  }

  /// Take photo with camera
  Future<String?> takePhotoWithCamera() async {
    try {
      _setStatus(MediaStatus.picking);
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        return await _processAndUploadImage(image);
      }
      
      _setStatus(MediaStatus.idle);
      return null;
    } catch (e) {
      _setError('Failed to take photo: $e');
      return null;
    }
  }

  /// Pick video from gallery
  Future<String?> pickVideoFromGallery() async {
    try {
      _setStatus(MediaStatus.picking);
      
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null) {
        return await _processAndUploadVideo(video);
      }
      
      _setStatus(MediaStatus.idle);
      return null;
    } catch (e) {
      _setError('Failed to pick video from gallery: $e');
      return null;
    }
  }

  /// Record video with camera
  Future<String?> recordVideoWithCamera() async {
    try {
      _setStatus(MediaStatus.picking);
      
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null) {
        return await _processAndUploadVideo(video);
      }
      
      _setStatus(MediaStatus.idle);
      return null;
    } catch (e) {
      _setError('Failed to record video: $e');
      return null;
    }
  }

  /// Process and upload image
  Future<String?> _processAndUploadImage(XFile image) async {
    try {
      _setStatus(MediaStatus.processing);
      
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Read image bytes
      final Uint8List imageBytes = await image.readAsBytes();
      
      _setStatus(MediaStatus.uploading);
      _uploadProgress = 0.0;
      notifyListeners();
      
      // Simulate upload progress
      _simulateUploadProgress();
      
      // Upload to Supabase Storage
      final imageUrl = await _storageService.uploadImage(
        imageBytes: imageBytes,
        userId: user.id,
        fileName: image.name,
        isTemporary: false,
      );
      
      if (imageUrl != null) {
        _currentMediaUrl = imageUrl;
        _currentMediaType = MediaType.photo;
        _setStatus(MediaStatus.completed);
        return imageUrl;
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      _setError('Failed to process image: $e');
      return null;
    }
  }

  /// Process and upload video
  Future<String?> _processAndUploadVideo(XFile video) async {
    try {
      _setStatus(MediaStatus.processing);
      
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Read video bytes
      final Uint8List videoBytes = await video.readAsBytes();
      
      _setStatus(MediaStatus.uploading);
      _uploadProgress = 0.0;
      notifyListeners();
      
      // Simulate upload progress
      _simulateUploadProgress();
      
      // Upload to Supabase Storage
      final videoUrl = await _storageService.uploadVideo(
        videoBytes: videoBytes,
        userId: user.id,
        fileName: video.name,
        isTemporary: false,
      );
      
      if (videoUrl != null) {
        _currentMediaUrl = videoUrl;
        _currentMediaType = MediaType.video;
        _setStatus(MediaStatus.completed);
        return videoUrl;
      } else {
        throw Exception('Failed to upload video');
      }
    } catch (e) {
      _setError('Failed to process video: $e');
      return null;
    }
  }

  /// Upload profile picture
  Future<String?> uploadProfilePicture(XFile image) async {
    try {
      _setStatus(MediaStatus.processing);
      
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final Uint8List imageBytes = await image.readAsBytes();
      
      _setStatus(MediaStatus.uploading);
      _uploadProgress = 0.0;
      notifyListeners();
      
      _simulateUploadProgress();
      
      final profileUrl = await _storageService.uploadProfilePicture(
        imageBytes: imageBytes,
        userId: user.id,
        fileName: image.name,
      );
      
      if (profileUrl != null) {
        // Update user profile with new image URL
        await _authService.updateProfile(profileImageUrl: profileUrl);
        _setStatus(MediaStatus.completed);
        return profileUrl;
      } else {
        throw Exception('Failed to upload profile picture');
      }
    } catch (e) {
      _setError('Failed to upload profile picture: $e');
      return null;
    }
  }

  /// Send media as post
  Future<bool> sendMediaAsPost({
    required String mediaUrl,
    required MediaType mediaType,
    String? caption,
    List<String>? recipientIds,
  }) async {
    try {
      _setStatus(MediaStatus.processing);
      
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Create post
      final postId = await _postsService.createPost(
        userId: user.id,
        content: caption ?? '',
        mediaUrl: mediaUrl,
        mediaType: mediaType == MediaType.photo ? 'photo' : 'video',
      );
      
      if (postId != null) {
        // Send to recipients if specified
        if (recipientIds != null && recipientIds.isNotEmpty) {
          for (final recipientId in recipientIds) {
            await _postsService.sendToUser(
              postId: postId,
              recipientId: recipientId,
            );
          }
        } else {
          // Send to random users
          await _postsService.sendToRandomUsers(
            postId: postId,
            count: 5, // Send to 5 random users
          );
        }
        
        _setStatus(MediaStatus.completed);
        return true;
      }
      
      return false;
    } catch (e) {
      _setError('Failed to send media: $e');
      return false;
    }
  }

  /// Download media
  Future<Uint8List?> downloadMedia(String mediaUrl) async {
    try {
      return await _storageService.downloadImage(mediaUrl);
    } catch (e) {
      _setError('Failed to download media: $e');
      return null;
    }
  }

  /// Delete media
  Future<bool> deleteMedia(String mediaUrl) async {
    try {
      // Extract bucket and path from URL
      final uri = Uri.parse(mediaUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 3) {
        final bucket = pathSegments[pathSegments.length - 3];
        final filePath = pathSegments.sublist(pathSegments.length - 2).join('/');
        
        return await _storageService.deleteFile(
          bucket: bucket,
          filePath: filePath,
        );
      }
      
      return false;
    } catch (e) {
      _setError('Failed to delete media: $e');
      return false;
    }
  }

  /// Get storage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      return await _storageService.getStorageStats(user.id);
    } catch (e) {
      _setError('Failed to get storage stats: $e');
      return {};
    }
  }

  /// Simulate upload progress for better UX
  void _simulateUploadProgress() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_status == MediaStatus.uploading && _uploadProgress < 0.9) {
        _uploadProgress += 0.1;
        notifyListeners();
        _simulateUploadProgress();
      }
    });
  }

  /// Set status and notify listeners
  void _setStatus(MediaStatus status) {
    _status = status;
    _errorMessage = null;
    if (status == MediaStatus.completed) {
      _uploadProgress = 1.0;
    } else if (status == MediaStatus.idle) {
      _uploadProgress = 0.0;
      _currentMediaUrl = null;
      _currentMediaType = null;
    }
    notifyListeners();
  }

  /// Set error and notify listeners
  void _setError(String error) {
    _status = MediaStatus.error;
    _errorMessage = error;
    _uploadProgress = 0.0;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_status == MediaStatus.error) {
      _status = MediaStatus.idle;
    }
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _status = MediaStatus.idle;
    _errorMessage = null;
    _currentMediaUrl = null;
    _currentMediaType = null;
    _uploadProgress = 0.0;
    notifyListeners();
  }
}