import 'dart:io';
import 'dart:math' as Math;
import 'package:flutter/foundation.dart';
import '../../data/services/face_recognition_service.dart';
import '../../data/services/supabase_face_service.dart';
import '../../data/services/supabase_auth_service.dart';

class FaceRecognitionProvider with ChangeNotifier {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final SupabaseFaceService _supabaseFaceService = SupabaseFaceService();
  final SupabaseAuthService _supabaseAuthService = SupabaseAuthService();
  
  bool _isLoading = false;
  bool _isConnected = false;
  Map<String, dynamic>? _lastResult;
  List<Map<String, dynamic>> _recognitionHistory = [];
  Map<String, dynamic> _settings = {};
  String? _error;
  bool _useSupabase = true; // Primary: Supabase, Fallback: Local service

  // Getters
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  Map<String, dynamic>? get lastResult => _lastResult;
  List<Map<String, dynamic>> get recognitionHistory => _recognitionHistory;
  Map<String, dynamic> get settings => _settings;
  String? get error => _error;

  /// Servis bağlantısını test et
  Future<void> testConnection() async {
    _setLoading(true);
    _clearError();
    
    try {
      _isConnected = await _faceService.testConnection();
      if (_isConnected) {
        await loadSettings();
        await loadRecognitionHistory();
      }
    } catch (e) {
      _setError('Bağlantı testi başarısız: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Yüz tespiti yap
  Future<void> detectFaces(File imageFile) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _faceService.detectFaces(imageFile);
      
      if (result != null && result['success'] == true) {
        _lastResult = result;
        
        // Sonuçları kaydet
        if (_settings['auto_save_results'] == true) {
          await _faceService.saveRecognitionResult(result);
          await loadRecognitionHistory();
        }
        
        notifyListeners();
      } else {
        _setError('Yüz tespiti başarısız');
      }
    } catch (e) {
      _setError('Yüz tespiti hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Gelişmiş yüz tanıma yap
  Future<void> recognizeFaces(File imageFile) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _faceService.recognizeFaces(imageFile);
      
      if (result != null && result['success'] == true) {
        _lastResult = result;
        
        // Sonuçları kaydet
        if (_settings['auto_save_results'] == true) {
          await _faceService.saveRecognitionResult(result);
          await loadRecognitionHistory();
        }
        
        notifyListeners();
      } else {
        _setError('Yüz tanıma başarısız');
      }
    } catch (e) {
      _setError('Yüz tanıma hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Kimlik doğrulama - profil resmi ile canlı resmi karşılaştır
  Future<Map<String, dynamic>?> verifyIdentity(
    File liveImageFile, 
    String profileImageUrl, 
    String userId
  ) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Önce canlı resimde yüz tespit et
      final liveDetection = await _faceService.detectFaces(liveImageFile);
      
      if (liveDetection == null || liveDetection['success'] != true) {
        _setError('Canlı resimde yüz tespit edilemedi');
        _setLoading(false);
        return null;
      }
      
      // Profil resmini indir ve analiz et
      if (profileImageUrl.isEmpty) {
        _setError('Profil resmi bulunamadı');
        _setLoading(false);
        return null;
      }
      
      // Supabase'den profil resmi verilerini al
      final profileFaceData = await _supabaseFaceService.getFaceData(userId);
      
      if (profileFaceData == null) {
        _setError('Profil yüz verisi bulunamadı');
        _setLoading(false);
        return null;
      }
      
      // Yüz karşılaştırması yap
      final liveFaces = liveDetection['faces'] as List?;
      if (liveFaces == null || liveFaces.isEmpty) {
        _setError('Canlı resimde yüz bulunamadı');
        _setLoading(false);
        return null;
      }
      
      final liveFace = liveFaces.first;
      final liveEncoding = liveFace['encoding'] as List?;
      
      if (liveEncoding == null) {
        _setError('Canlı yüz encoding alınamadı');
        _setLoading(false);
        return null;
      }
      
      // Benzerlik skoru hesapla
      final similarityScore = _calculateSimilarity(
        liveEncoding.cast<double>(),
        (profileFaceData['encoding'] as List).cast<double>(),
      );
      
      // Doğrulama kriterleri
      final isVerified = similarityScore > 0.7; // %70 benzerlik
      final confidence = liveFace['confidence'] as double? ?? 0.0;
      
      // Anti-spoofing kontrolü
      final isSpoof = liveFace['is_spoof'] as bool? ?? false;
      
      final result = {
        'is_verified': isVerified && !isSpoof && confidence > 0.6,
        'similarity_score': similarityScore,
        'confidence': confidence,
        'is_spoof': isSpoof,
        'result': isVerified && !isSpoof && confidence > 0.6 
            ? 'Kimlik doğrulandı' 
            : 'Kimlik doğrulanamadı',
        'processing_time': liveDetection['processing_time'] ?? 0.0,
      };
      
      _lastResult = result;
      notifyListeners();
      _setLoading(false);
      
      return result;
      
    } catch (e) {
      _setError('Kimlik doğrulama hatası: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Yüz encoding'leri arasındaki benzerliği hesapla
  double _calculateSimilarity(List<double> encoding1, List<double> encoding2) {
    if (encoding1.length != encoding2.length) return 0.0;
    
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < encoding1.length; i++) {
      dotProduct += encoding1[i] * encoding2[i];
      norm1 += encoding1[i] * encoding1[i];
      norm2 += encoding2[i] * encoding2[i];
    }
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    
    return dotProduct / (Math.sqrt(norm1) * Math.sqrt(norm2));
  }

  /// Yeni yüz ekle
  Future<bool> addFace(File imageFile, String userId, String name) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (_useSupabase) {
        // First, get face encoding from local service
        final detectionResult = await _faceService.detectFaces(imageFile);
        
        if (detectionResult != null && detectionResult['success'] == true) {
          final faces = detectionResult['faces'] as List?;
          if (faces != null && faces.isNotEmpty) {
            final faceData = faces.first;
            
            // Save to Supabase
            final faceId = await _supabaseFaceService.saveFaceData(
              userId: userId,
              faceEncoding: {
                'encoding': faceData['encoding'] ?? [],
                'landmarks': faceData['landmarks'] ?? [],
              },
              confidence: (faceData['confidence'] as num?)?.toDouble(),
              gender: faceData['gender'] as String?,
              ageEstimate: faceData['age'] as int?,
            );
            
            if (faceId != null) {
              // Also save to local service for immediate use
              await _faceService.addFace(imageFile, userId, name);
              await loadRecognitionHistory();
              _setLoading(false);
              return true;
            }
          }
        }
        
        _setError('Yüz tespiti başarısız');
        _setLoading(false);
        return false;
      } else {
        // Fallback to local service
        final result = await _faceService.addFace(imageFile, userId, name);
        
        if (result != null && result['success'] == true) {
          _setLoading(false);
          return true;
        } else {
          _setError('Yüz ekleme başarısız');
          _setLoading(false);
          return false;
        }
      }
    } catch (e) {
      _setError('Yüz ekleme hatası: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Servis istatistiklerini al
  Future<Map<String, dynamic>?> getServiceStats() async {
    try {
      if (_useSupabase) {
        final supabaseStats = await _supabaseFaceService.getFaceStats();
        final localStats = await _faceService.getServiceStats();
        
        return {
          'supabase': supabaseStats,
          'local': localStats,
          'data_source': 'hybrid',
        };
      } else {
        return await _faceService.getServiceStats();
      }
    } catch (e) {
      _setError('İstatistik alma hatası: $e');
      return null;
    }
  }

  /// Bilinen yüzleri al
  Future<List<String>?> getKnownFaces() async {
    try {
      return await _faceService.getKnownFaces();
    } catch (e) {
      _setError('Bilinen yüzleri alma hatası: $e');
      return null;
    }
  }

  /// Yüz sil
  Future<bool> deleteFace(String userId) async {
    try {
      bool success = false;
      
      if (_useSupabase) {
        // Delete from Supabase
        success = await _supabaseFaceService.deleteUserFaceData(userId);
        
        // Also delete from local service
        if (success) {
          await _faceService.deleteFace(userId);
        }
      } else {
        success = await _faceService.deleteFace(userId);
      }
      
      if (success) {
        await loadRecognitionHistory();
      }
      return success;
    } catch (e) {
      _setError('Yüz silme hatası: $e');
      return false;
    }
  }

  /// Tanıma geçmişini yükle
  Future<void> loadRecognitionHistory() async {
    try {
      if (_useSupabase && _supabaseAuthService.currentUser != null) {
        // Load from Supabase
        final supabaseFaceData = await _supabaseFaceService.getUserFaceData(
          _supabaseAuthService.currentUser!.id,
        );
        
        // Convert Supabase data to recognition history format
        _recognitionHistory = supabaseFaceData.map((faceData) => {
          'id': faceData['id'],
          'user_id': faceData['user_id'],
          'confidence': faceData['confidence'] ?? 0.0,
          'gender': faceData['gender'],
          'age': faceData['age_estimate'],
          'created_at': faceData['created_at'],
          'source': 'supabase',
        }).toList();
        
        // Also load local history for comparison
        final localHistory = await _faceService.getRecognitionResults();
        
        // Merge with local history
        for (final localResult in localHistory) {
          _recognitionHistory.add({
            ...localResult,
            'source': 'local',
          });
        }
      } else {
        _recognitionHistory = await _faceService.getRecognitionResults();
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Geçmiş yükleme hatası: $e');
    }
  }

  /// Ayarları yükle
  Future<void> loadSettings() async {
    try {
      _settings = await _faceService.getSettings();
      notifyListeners();
    } catch (e) {
      _setError('Ayar yükleme hatası: $e');
    }
  }

  /// Ayar güncelle
  Future<void> updateSetting(String key, dynamic value) async {
    try {
      _settings[key] = value;
      await _faceService.saveSettings(_settings);
      notifyListeners();
    } catch (e) {
      _setError('Ayar güncelleme hatası: $e');
    }
  }

  /// Sonuçları temizle
  void clearResults() {
    _lastResult = null;
    _recognitionHistory.clear();
    notifyListeners();
  }

  /// Hata temizle
  void _clearError() {
    _error = null;
  }

  /// Hata ayarla
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Loading durumunu ayarla
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Sonuçtan yüz sayısını al
  int getFaceCount() {
    if (_lastResult != null) {
      return _lastResult!['faces_detected'] ?? 0;
    }
    return 0;
  }

  /// Sonuçtan tespit edilen yüzleri al
  List<dynamic> getDetectedFaces() {
    if (_lastResult != null) {
      return _lastResult!['faces'] ?? [];
    }
    return [];
  }

  /// Sonuçtan tanınan yüzleri al
  List<dynamic> getRecognizedFaces() {
    if (_lastResult != null) {
      return _lastResult!['faces_analyzed'] ?? [];
    }
    return [];
  }

  /// Risk skorunu al
  double getRiskScore() {
    if (_lastResult != null) {
      return (_lastResult!['overall_risk_score'] ?? 0.0).toDouble();
    }
    return 0.0;
  }

  /// İşlem süresini al
  double getProcessingTime() {
    if (_lastResult != null) {
      return (_lastResult!['processing_time'] ?? 0.0).toDouble();
    }
    return 0.0;
  }

  /// Cinsiyet tespiti etkin mi?
  bool get isGenderDetectionEnabled => _settings['enable_gender_detection'] ?? true;

  /// Anti-spoofing etkin mi?
  bool get isAntiSpoofEnabled => _settings['enable_anti_spoof'] ?? true;

  /// Yüz tanıma etkin mi?
  bool get isFaceRecognitionEnabled => _settings['enable_face_recognition'] ?? true;

  /// Güven eşiği
  double get confidenceThreshold => (_settings['confidence_threshold'] ?? 0.6).toDouble();

  /// Cinsiyet tespiti
  Future<void> detectGender(File imageFile) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _faceService.detectGender(imageFile);
      
      if (result != null && result['success'] == true) {
        _lastResult = result;
        
        // Sonuçları kaydet
        if (_settings['auto_save_results'] == true) {
          await _faceService.saveRecognitionResult(result);
          await loadRecognitionHistory();
        }
        
        notifyListeners();
      } else {
        _setError('Cinsiyet tespiti başarısız');
      }
    } catch (e) {
      _setError('Cinsiyet tespiti hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Anti-spoofing tespiti
  Future<void> antiSpoofDetection(File imageFile) async {
    _setLoading(true);
    _clearError();
    
    try {
      final result = await _faceService.antiSpoofDetection(imageFile);
      
      if (result != null && result['success'] == true) {
        _lastResult = result;
        
        // Sonuçları kaydet
        if (_settings['auto_save_results'] == true) {
          await _faceService.saveRecognitionResult(result);
          await loadRecognitionHistory();
        }
        
        notifyListeners();
      } else {
        _setError('Anti-spoofing tespiti başarısız');
      }
    } catch (e) {
      _setError('Anti-spoofing tespiti hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle between Supabase and local service
  void toggleDataSource() {
    _useSupabase = !_useSupabase;
    notifyListeners();
  }

  bool get useSupabase => _useSupabase;

  /// Migrate local face data to Supabase
  Future<bool> migrateToSupabase() async {
    if (!_useSupabase || _supabaseAuthService.currentUser == null) {
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      // Get local recognition history
      final localHistory = await _faceService.getRecognitionResults();
      
      // Convert and batch save to Supabase
      final faceDataList = <Map<String, dynamic>>[];
      
      for (final result in localHistory) {
        if (result['faces'] != null) {
          final faces = result['faces'] as List;
          for (final face in faces) {
            faceDataList.add({
              'user_id': _supabaseAuthService.currentUser!.id,
              'face_encoding': {
                'encoding': face['encoding'] ?? [],
                'landmarks': face['landmarks'] ?? [],
              },
              'confidence': (face['confidence'] as num?)?.toDouble(),
              'gender': face['gender'] as String?,
              'age_estimate': face['age'] as int?,
            });
          }
        }
      }
      
      if (faceDataList.isNotEmpty) {
        final success = await _supabaseFaceService.batchSaveFaceData(faceDataList);
        if (success) {
          await loadRecognitionHistory();
          _setLoading(false);
          return true;
        }
      }
      
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Migration hatası: $e');
      _setLoading(false);
      return false;
    }
  }
}
