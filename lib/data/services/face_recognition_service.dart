import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FaceRecognitionService {
  static const String _baseUrl = 'https://sendpic-face-api.railway.app';
  static const String _apiKey = 'face_recognition_key';
  
  // Singleton pattern
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  /// Yüz tanıma API'sini test et
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Yüz tanıma servisi bağlantı hatası: $e');
      return false;
    }
  }

  /// Resimde yüz tespiti yap
  Future<Map<String, dynamic>?> detectFaces(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/test/face-detection'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final result = json.decode(responseData);
        print('Yüz tespiti başarılı: ${result['faces_detected']} yüz bulundu');
        return result;
      } else {
        print('Yüz tespiti hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Yüz tespiti servisi hatası: $e');
      return null;
    }
  }

  /// Gelişmiş yüz tanıma (tam API ile)
  Future<Map<String, dynamic>?> recognizeFaces(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/recognize'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final result = json.decode(responseData);
        print('Yüz tanıma başarılı: ${result['faces_detected']} yüz bulundu');
        return result;
      } else {
        print('Yüz tanıma hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Yüz tanıma servisi hatası: $e');
      return null;
    }
  }

  /// Yeni yüz ekle
  Future<Map<String, dynamic>?> addFace(File imageFile, String userId, String name) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/add-face'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      
      request.fields['user_id'] = userId;
      request.fields['name'] = name;
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        print('Yüz ekleme hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Yüz ekleme servisi hatası: $e');
      return null;
    }
  }

  /// Servis istatistiklerini al
  Future<Map<String, dynamic>?> getServiceStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/stats'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('İstatistik alma hatası: $e');
      return null;
    }
  }

  /// Bilinen yüzleri al
  Future<List<String>?> getKnownFaces() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/faces'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['known_users'] ?? []);
      }
      return null;
    } catch (e) {
      print('Bilinen yüzleri alma hatası: $e');
      return null;
    }
  }

  /// Yüz sil
  Future<bool> deleteFace(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/faces/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Yüz silme hatası: $e');
      return false;
    }
  }

  /// Yüz tanıma sonuçlarını kaydet
  Future<void> saveRecognitionResult(Map<String, dynamic> result) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final results = prefs.getStringList('face_recognition_results') ?? [];
      
      results.add(json.encode(result));
      
      // Son 100 sonucu sakla
      if (results.length > 100) {
        results.removeAt(0);
      }
      
      await prefs.setStringList('face_recognition_results', results);
    } catch (e) {
      print('Sonuç kaydetme hatası: $e');
    }
  }

  /// Yüz tanıma sonuçlarını al
  Future<List<Map<String, dynamic>>> getRecognitionResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final results = prefs.getStringList('face_recognition_results') ?? [];
      
      return results.map((result) => json.decode(result) as Map<String, dynamic>).toList();
    } catch (e) {
      print('Sonuç alma hatası: $e');
      return [];
    }
  }

  /// Yüz tanıma ayarlarını kaydet
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('face_recognition_settings', json.encode(settings));
    } catch (e) {
      print('Ayar kaydetme hatası: $e');
    }
  }

  /// Yüz tanıma ayarlarını al
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = prefs.getString('face_recognition_settings');
      
      if (settings != null) {
        return json.decode(settings) as Map<String, dynamic>;
      }
      
      // Varsayılan ayarlar
      return {
        'enable_face_recognition': true,
        'enable_gender_detection': true,
        'enable_anti_spoof': true,
        'confidence_threshold': 0.6,
        'auto_save_results': true,
      };
    } catch (e) {
      print('Ayar alma hatası: $e');
      return {};
    }
  }

  /// Cinsiyet tespiti
  Future<Map<String, dynamic>?> detectGender(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/gender-detection'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final result = json.decode(responseData);
        print('Cinsiyet tespiti başarılı: ${result['faces_detected']} yüz analiz edildi');
        return result;
      } else {
        print('Cinsiyet tespiti hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Cinsiyet tespiti servisi hatası: $e');
      return null;
    }
  }

  /// Anti-spoofing tespiti
  Future<Map<String, dynamic>?> antiSpoofDetection(File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/anti-spoof'),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );
      
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final result = json.decode(responseData);
        print('Anti-spoofing tespiti başarılı: ${result['faces_detected']} yüz kontrol edildi');
        return result;
      } else {
        print('Anti-spoofing tespiti hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Anti-spoofing tespiti servisi hatası: $e');
      return null;
    }
  }

  /// Servis sağlık kontrolü
  Future<bool> getHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Yüz tanıma servisi bağlantı hatası: $e');
      return false;
    }
  }
}
