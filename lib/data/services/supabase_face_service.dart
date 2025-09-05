import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class SupabaseFaceService {
  static final SupabaseFaceService _instance = SupabaseFaceService._internal();
  factory SupabaseFaceService() => _instance;
  SupabaseFaceService._internal();

  SupabaseClient get _client => SupabaseConfig.client;

  // Save face data to Supabase
  Future<String?> saveFaceData({
    required String userId,
    required Map<String, dynamic> faceEncoding,
    String? imageUrl,
    double? confidence,
    String? gender,
    int? ageEstimate,
  }) async {
    try {
      final response = await _client.from('face_data').insert({
        'user_id': userId,
        'face_encoding': faceEncoding,
        'image_url': imageUrl,
        'confidence': confidence,
        'gender': gender,
        'age_estimate': ageEstimate,
      }).select().single();

      return response['id'] as String;
    } catch (e) {
      print('Error saving face data: $e');
      return null;
    }
  }

  // Get user's face data
  Future<List<Map<String, dynamic>>> getUserFaceData(String userId) async {
    try {
      final response = await _client
          .from('face_data')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user face data: $e');
      return [];
    }
  }

  // Get specific face data for verification
  Future<Map<String, dynamic>?> getFaceData(String userId) async {
    try {
      final response = await _client
          .from('face_data')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .single();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting face data: $e');
      return null;
    }
  }

  // Get all face encodings for recognition
  Future<List<Map<String, dynamic>>> getAllFaceEncodings() async {
    try {
      final response = await _client
          .from('face_data')
          .select('''
            id,
            user_id,
            face_encoding,
            confidence,
            users!face_data_user_id_fkey(
              id,
              name,
              profile_image_url
            )
          ''');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting all face encodings: $e');
      return [];
    }
  }

  // Update face data
  Future<bool> updateFaceData({
    required String faceDataId,
    Map<String, dynamic>? faceEncoding,
    String? imageUrl,
    double? confidence,
    String? gender,
    int? ageEstimate,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (faceEncoding != null) updates['face_encoding'] = faceEncoding;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (confidence != null) updates['confidence'] = confidence;
      if (gender != null) updates['gender'] = gender;
      if (ageEstimate != null) updates['age_estimate'] = ageEstimate;

      if (updates.isEmpty) return false;

      await _client
          .from('face_data')
          .update(updates)
          .eq('id', faceDataId);

      return true;
    } catch (e) {
      print('Error updating face data: $e');
      return false;
    }
  }

  // Delete face data
  Future<bool> deleteFaceData(String faceDataId) async {
    try {
      await _client
          .from('face_data')
          .delete()
          .eq('id', faceDataId);

      return true;
    } catch (e) {
      print('Error deleting face data: $e');
      return false;
    }
  }

  // Delete all face data for a user
  Future<bool> deleteUserFaceData(String userId) async {
    try {
      await _client
          .from('face_data')
          .delete()
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('Error deleting user face data: $e');
      return false;
    }
  }

  // Search for similar faces (for recognition)
  Future<List<Map<String, dynamic>>> searchSimilarFaces({
    required Map<String, dynamic> queryEncoding,
    double threshold = 0.6,
    int limit = 10,
  }) async {
    try {
      // Note: This is a simplified approach. In a real application,
      // you would use a vector database or implement cosine similarity
      // in PostgreSQL using extensions like pgvector
      
      final allFaces = await getAllFaceEncodings();
      final similarities = <Map<String, dynamic>>[];

      for (final face in allFaces) {
        final encoding = face['face_encoding'] as Map<String, dynamic>;
        final similarity = _calculateCosineSimilarity(queryEncoding, encoding);
        
        if (similarity >= threshold) {
          similarities.add({
            ...face,
            'similarity': similarity,
          });
        }
      }

      // Sort by similarity (highest first)
      similarities.sort((a, b) => 
          (b['similarity'] as double).compareTo(a['similarity'] as double));

      return similarities.take(limit).toList();
    } catch (e) {
      print('Error searching similar faces: $e');
      return [];
    }
  }

  // Calculate cosine similarity between two face encodings
  double _calculateCosineSimilarity(
    Map<String, dynamic> encoding1,
    Map<String, dynamic> encoding2,
  ) {
    try {
      // Convert encodings to lists of doubles
      final List<double> vec1 = (encoding1['encoding'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final List<double> vec2 = (encoding2['encoding'] as List)
          .map((e) => (e as num).toDouble())
          .toList();

      if (vec1.length != vec2.length) return 0.0;

      double dotProduct = 0.0;
      double norm1 = 0.0;
      double norm2 = 0.0;

      for (int i = 0; i < vec1.length; i++) {
        dotProduct += vec1[i] * vec2[i];
        norm1 += vec1[i] * vec1[i];
        norm2 += vec2[i] * vec2[i];
      }

      if (norm1 == 0.0 || norm2 == 0.0) return 0.0;

      return dotProduct / (sqrt(norm1) * sqrt(norm2));
    } catch (e) {
      print('Error calculating cosine similarity: $e');
      return 0.0;
    }
  }

  // Helper function for square root
  double sqrt(double value) {
    if (value < 0) return 0.0;
    double x = value;
    double prev = 0.0;
    
    while ((x - prev).abs() > 0.0001) {
      prev = x;
      x = (x + value / x) / 2;
    }
    
    return x;
  }

  // Get face recognition statistics
  Future<Map<String, dynamic>> getFaceStats() async {
    try {
      // Get all face data for counting
      final allFacesResponse = await _client
          .from('face_data')
          .select('user_id, gender');
      
      final uniqueUsers = <String>{};
      final genderStats = <String, int>{};
      
      for (final row in allFacesResponse) {
        // Count unique users
        uniqueUsers.add(row['user_id'] as String);
        
        // Count gender distribution
        final gender = row['gender'] as String? ?? 'unknown';
        genderStats[gender] = (genderStats[gender] ?? 0) + 1;
      }

      return {
        'total_faces': allFacesResponse.length,
        'unique_users': uniqueUsers.length,
        'gender_distribution': genderStats,
      };
    } catch (e) {
      print('Error getting face stats: $e');
      return {
        'total_faces': 0,
        'unique_users': 0,
        'gender_distribution': <String, int>{},
      };
    }
  }

  // Batch save face data (for migration)
  Future<bool> batchSaveFaceData(List<Map<String, dynamic>> faceDataList) async {
    try {
      await _client.from('face_data').insert(faceDataList);
      return true;
    } catch (e) {
      print('Error batch saving face data: $e');
      return false;
    }
  }

  // Export face data for backup
  Future<List<Map<String, dynamic>>> exportFaceData(String userId) async {
    try {
      final response = await _client
          .from('face_data')
          .select()
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error exporting face data: $e');
      return [];
    }
  }
}