import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraStatus { initial, loading, ready, error, capturing }

class CameraProvider with ChangeNotifier {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraStatus _status = CameraStatus.initial;
  String? _errorMessage;
  File? _capturedImage;
  File? _capturedVideo;
  bool _isRecording = false;
  int _currentCameraIndex = 0;

  // Getters
  CameraController? get controller => _controller;
  CameraStatus get status => _status;
  String? get errorMessage => _errorMessage;
  File? get capturedImage => _capturedImage;
  File? get capturedVideo => _capturedVideo;
  bool get isRecording => _isRecording;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get hasCameras => _cameras.isNotEmpty;
  int get currentCameraIndex => _currentCameraIndex;

  Future<void> initializeCamera() async {
    _status = CameraStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // Web platformunda kamera desteği yok
    if (kIsWeb) {
      _status = CameraStatus.error;
      _errorMessage = 'Web platformunda kamera özelliği desteklenmemektedir. Lütfen mobil uygulamayı indirin.';
      notifyListeners();
      return;
    }

    try {
      // Check camera permission
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _status = CameraStatus.error;
        _errorMessage = 'Kamera izni gereklidir';
        notifyListeners();
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _status = CameraStatus.error;
        _errorMessage = 'Kamera bulunamadı';
        notifyListeners();
        return;
      }

      // Initialize camera controller
      await _initializeCameraController(_currentCameraIndex);
    } catch (e) {
      _status = CameraStatus.error;
      _errorMessage = 'Kamera başlatılamadı: $e';
      notifyListeners();
    }
  }

  Future<void> _initializeCameraController(int cameraIndex) async {
    // Dispose previous controller if exists
    await _controller?.dispose();

    _controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      _status = CameraStatus.ready;
      _errorMessage = null;
    } catch (e) {
      _status = CameraStatus.error;
      _errorMessage = 'Kamera başlatılamadı: $e';
    }
    
    notifyListeners();
  }

  Future<File?> capturePhoto() async {
    // Web platformunda fotoğraf çekme desteği yok
    if (kIsWeb) {
      _errorMessage = 'Web platformunda fotoğraf çekme özelliği desteklenmemektedir.';
      notifyListeners();
      return null;
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = 'Kamera hazır değil';
      notifyListeners();
      return null;
    }

    _status = CameraStatus.capturing;
    notifyListeners();

    try {
      final XFile image = await _controller!.takePicture();
      _capturedImage = File(image.path);
      _capturedVideo = null; // Clear video if exists
      
      _status = CameraStatus.ready;
      notifyListeners();
      return _capturedImage;
    } catch (e) {
      _status = CameraStatus.error;
      _errorMessage = 'Fotoğraf çekilemedi: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> startVideoRecording() async {
    // Web platformunda video kayıt desteği yok
    if (kIsWeb) {
      _errorMessage = 'Web platformunda video kayıt özelliği desteklenmemektedir.';
      notifyListeners();
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      _errorMessage = 'Kamera hazır değil';
      notifyListeners();
      return;
    }

    if (_isRecording) return;

    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      _status = CameraStatus.capturing;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Video kaydı başlatılamadı: $e';
      notifyListeners();
    }
  }

  Future<File?> stopVideoRecording() async {
    // Web platformunda video kayıt desteği yok
    if (kIsWeb) {
      _errorMessage = 'Web platformunda video kayıt özelliği desteklenmemektedir.';
      notifyListeners();
      return null;
    }

    if (_controller == null || !_isRecording) {
      return null;
    }

    try {
      final XFile video = await _controller!.stopVideoRecording();
      _capturedVideo = File(video.path);
      _capturedImage = null; // Clear image if exists
      _isRecording = false;
      
      _status = CameraStatus.ready;
      notifyListeners();
      return _capturedVideo;
    } catch (e) {
      _errorMessage = 'Video kaydı durdurulamadı: $e';
      _isRecording = false;
      _status = CameraStatus.error;
      notifyListeners();
      return null;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length <= 1) return;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initializeCameraController(_currentCameraIndex);
  }

  Future<void> toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final currentFlashMode = _controller!.value.flashMode;
      final newFlashMode = currentFlashMode == FlashMode.off 
          ? FlashMode.auto 
          : FlashMode.off;
      
      await _controller!.setFlashMode(newFlashMode);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Flaş ayarı değiştirilemedi: $e';
      notifyListeners();
    }
  }

  void clearCapturedMedia() {
    _capturedImage = null;
    _capturedVideo = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Helper methods
  bool get hasFlash {
    if (_controller == null || !_controller!.value.isInitialized) {
      return false;
    }
    return _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.back;
  }

  bool get isFlashOn {
    return _controller?.value.flashMode != FlashMode.off;
  }

  bool get isFrontCamera {
    if (_cameras.isEmpty) return false;
    return _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;
  }

  bool get isBackCamera {
    if (_cameras.isEmpty) return false;
    return _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.back;
  }
}
