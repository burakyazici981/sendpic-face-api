import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  final Uuid _uuid = const Uuid();

  // Get app directories
  Future<Directory> get _documentsDirectory async {
    return await getApplicationDocumentsDirectory();
  }

  Future<Directory> get _mediaDirectory async {
    final docs = await _documentsDirectory;
    final mediaDir = Directory('${docs.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  Future<Directory> get _profileImagesDirectory async {
    final docs = await _documentsDirectory;
    final profileDir = Directory('${docs.path}/profile_images');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    return profileDir;
  }

  // Save file from File object
  Future<String?> saveFile(File file, String bucket) async {
    try {
      final Directory targetDir;
      
      switch (bucket) {
        case 'media':
          targetDir = await _mediaDirectory;
          break;
        case 'profile-images':
          targetDir = await _profileImagesDirectory;
          break;
        default:
          targetDir = await _documentsDirectory;
      }

      // Generate unique filename
      final fileExtension = extension(file.path);
      final fileName = '${_uuid.v4()}$fileExtension';
      final targetPath = '${targetDir.path}/$fileName';

      // Copy file to target location
      await file.copy(targetPath);
      
      return targetPath;
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  // Save file from bytes
  Future<String?> saveFileFromBytes(
    Uint8List bytes, 
    String fileName, 
    String bucket
  ) async {
    try {
      final Directory targetDir;
      
      switch (bucket) {
        case 'media':
          targetDir = await _mediaDirectory;
          break;
        case 'profile-images':
          targetDir = await _profileImagesDirectory;
          break;
        default:
          targetDir = await _documentsDirectory;
      }

      // Generate unique filename if not provided
      final finalFileName = fileName.isNotEmpty 
          ? fileName 
          : '${_uuid.v4()}.jpg';
      
      final targetPath = '${targetDir.path}/$finalFileName';
      final file = File(targetPath);
      
      await file.writeAsBytes(bytes);
      
      return targetPath;
    } catch (e) {
      print('Error saving file from bytes: $e');
      return null;
    }
  }

  // Get file
  Future<File?> getFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error getting file: $e');
      return null;
    }
  }

  // Delete file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // Get file size
  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }

  // List files in bucket
  Future<List<String>> listFiles(String bucket) async {
    try {
      final Directory targetDir;
      
      switch (bucket) {
        case 'media':
          targetDir = await _mediaDirectory;
          break;
        case 'profile-images':
          targetDir = await _profileImagesDirectory;
          break;
        default:
          targetDir = await _documentsDirectory;
      }

      if (!await targetDir.exists()) {
        return [];
      }

      final files = await targetDir.list().toList();
      return files
          .where((entity) => entity is File)
          .map((file) => file.path)
          .toList();
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }

  // Clear bucket
  Future<bool> clearBucket(String bucket) async {
    try {
      final Directory targetDir;
      
      switch (bucket) {
        case 'media':
          targetDir = await _mediaDirectory;
          break;
        case 'profile-images':
          targetDir = await _profileImagesDirectory;
          break;
        default:
          targetDir = await _documentsDirectory;
      }

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
        await targetDir.create(recursive: true);
      }
      
      return true;
    } catch (e) {
      print('Error clearing bucket: $e');
      return false;
    }
  }

  // Get total storage usage
  Future<int> getTotalStorageUsage() async {
    try {
      int totalSize = 0;
      
      final mediaDir = await _mediaDirectory;
      final profileDir = await _profileImagesDirectory;
      
      // Calculate media directory size
      if (await mediaDir.exists()) {
        final mediaFiles = await mediaDir.list(recursive: true).toList();
        for (final entity in mediaFiles) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      // Calculate profile images directory size
      if (await profileDir.exists()) {
        final profileFiles = await profileDir.list(recursive: true).toList();
        for (final entity in profileFiles) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error calculating storage usage: $e');
      return 0;
    }
  }

  // Format bytes to human readable string
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
