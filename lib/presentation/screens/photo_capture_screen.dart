import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isRecording = false;
  bool _isFrontCamera = false;
  String _captureMode = 'photo'; // 'photo' or 'video'
  File? _capturedImage;
  File? _capturedVideo;
  String _statusMessage = 'Kamera başlatılıyor...';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        // Start with front camera if available
        final frontCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras![0],
        );
        
        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.high,
          enableAudio: true, // Enable audio for video recording
        );
        
        await _cameraController!.initialize();
        setState(() {
          _isInitialized = true;
          _isFrontCamera = frontCamera.lensDirection == CameraLensDirection.front;
          _statusMessage = 'Fotoğraf veya video çekin ve rasgele birine gönderin';
        });
      } else {
        setState(() {
          _statusMessage = 'Kamera bulunamadı';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Kamera hatası: $e';
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Fotoğraf çekiliyor...';
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);
      
      setState(() {
        _capturedImage = imageFile;
        _statusMessage = 'Fotoğraf çekildi! Göndermek için onaylayın';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Fotoğraf çekme hatası: $e';
      });
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _sendPhoto() async {
    if (_capturedImage == null) return;

    setState(() {
      _statusMessage = 'Fotoğraf gönderiliyor...';
    });

    try {
      final contentProvider = context.read<ContentProvider>();
      final authProvider = context.read<AuthProvider>();
      
      if (authProvider.currentUser == null) {
        setState(() {
          _statusMessage = 'Lütfen önce giriş yapın';
        });
        return;
      }

      // Rasgele birine gönder
      final success = await contentProvider.sendRandomPhoto(
        _capturedImage!,
        authProvider.currentUser!.id,
      );

      if (success) {
        setState(() {
          _statusMessage = 'Fotoğraf başarıyla gönderildi! ✅';
        });
        
        // 2 saniye sonra yeni fotoğraf çekmeye hazır hale getir
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _capturedImage = null;
            _statusMessage = 'Yeni fotoğraf çekin';
          });
        });
      } else {
        setState(() {
          _statusMessage = 'Fotoğraf gönderilemedi. Tekrar deneyin.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Gönderim hatası: $e';
      });
    }
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isRecording = true;
      _statusMessage = 'Video kaydediliyor...';
    });

    try {
      await _cameraController!.startVideoRecording();
    } catch (e) {
      setState(() {
        _statusMessage = 'Video kaydetme hatası: $e';
        _isRecording = false;
      });
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null || !_isRecording) {
      return;
    }

    try {
      final XFile video = await _cameraController!.stopVideoRecording();
      final File videoFile = File(video.path);
      
      setState(() {
        _capturedVideo = videoFile;
        _isRecording = false;
        _statusMessage = 'Video kaydedildi! Göndermek için onaylayın';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Video kaydetme hatası: $e';
        _isRecording = false;
      });
    }
  }

  Future<void> _sendVideo() async {
    if (_capturedVideo == null) return;

    setState(() {
      _statusMessage = 'Video gönderiliyor...';
    });

    try {
      final contentProvider = context.read<ContentProvider>();
      final authProvider = context.read<AuthProvider>();
      
      if (authProvider.currentUser == null) {
        setState(() {
          _statusMessage = 'Lütfen önce giriş yapın';
        });
        return;
      }

      // Rasgele birine gönder
      final success = await contentProvider.sendRandomVideo(
        _capturedVideo!,
        authProvider.currentUser!.id,
      );

      if (success) {
        setState(() {
          _statusMessage = 'Video başarıyla gönderildi! ✅';
        });
        
        // 2 saniye sonra yeni video çekmeye hazır hale getir
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _capturedVideo = null;
            _statusMessage = 'Yeni video çekin';
          });
        });
      } else {
        setState(() {
          _statusMessage = 'Video gönderilemedi. Tekrar deneyin.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Gönderim hatası: $e';
      });
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
      _capturedVideo = null;
      _statusMessage = 'Yeni fotoğraf çekin';
    });
  }

  void _switchCaptureMode() {
    setState(() {
      _captureMode = _captureMode == 'photo' ? 'video' : 'photo';
      _capturedImage = null;
      _capturedVideo = null;
      _statusMessage = _captureMode == 'photo' 
          ? 'Fotoğraf çekin' 
          : 'Video çekin';
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SendPic'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _toggleFlash(),
          ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: () => _switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Kamera önizleme veya çekilen fotoğraf
          Expanded(
            flex: 4,
            child: _buildCameraView(),
          ),
          
          // Durum mesajı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Kontrol butonları
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (_capturedImage != null) {
      // Çekilen fotoğrafı göster
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(_capturedImage!),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
          ),
        ),
      );
    }

    if (_capturedVideo != null) {
      // Çekilen videoyu göster
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Video player placeholder
            const Center(
              child: Icon(
                Icons.videocam,
                color: Colors.white,
                size: 80,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Kamera önizlemesi
    if (!_isInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return Stack(
      children: [
        CameraPreview(_cameraController!),
        
        // Çekim çerçevesi
        Center(
          child: Container(
            width: 300,
            height: 400,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isCapturing ? Colors.orange : Colors.white,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        
        // İşlem göstergesi
        if (_isCapturing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Fotoğraf çekiliyor...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Mod değiştirme butonu
          if (_capturedImage == null && _capturedVideo == null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeButton('photo', Icons.camera_alt, 'Fotoğraf'),
                        _buildModeButton('video', Icons.videocam, 'Video'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          // Ana kontrol butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_capturedImage != null || _capturedVideo != null) ...[
                // Yeniden çek butonu
                FloatingActionButton(
                  onPressed: _retakePhoto,
                  backgroundColor: Colors.grey[700],
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
                
                const SizedBox(width: 20),
                
                // Gönder butonu
                FloatingActionButton.extended(
                  onPressed: _capturedImage != null ? _sendPhoto : _sendVideo,
                  backgroundColor: AppTheme.primaryColor,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _capturedImage != null ? 'Fotoğraf Gönder' : 'Video Gönder',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ] else ...[
                // Çek/Kaydet butonu
                FloatingActionButton(
                  onPressed: _isCapturing || _isRecording 
                      ? null 
                      : (_captureMode == 'photo' ? _capturePhoto : _startVideoRecording),
                  backgroundColor: _isCapturing || _isRecording ? Colors.grey : Colors.white,
                  child: Icon(
                    _isCapturing || _isRecording 
                        ? Icons.hourglass_empty 
                        : (_captureMode == 'photo' ? Icons.camera_alt : Icons.videocam),
                    color: _isCapturing || _isRecording ? Colors.grey : Colors.black,
                    size: 30,
                  ),
                ),
                
                // Video kaydı durdurma butonu
                if (_isRecording) ...[
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    onPressed: _stopVideoRecording,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.stop, color: Colors.white),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(String mode, IconData icon, String label) {
    final isSelected = _captureMode == mode;
    return GestureDetector(
      onTap: () => _switchCaptureMode(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFlash() {
    // Flash toggle functionality
    // Implementation depends on camera controller
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    
    final currentCamera = _cameraController!.description;
    final newCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection != currentCamera.lensDirection,
    );
    
    _cameraController?.dispose();
    _cameraController = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: true, // Enable audio for video recording
    );
    
    _cameraController!.initialize().then((_) {
      setState(() {
        _isFrontCamera = newCamera.lensDirection == CameraLensDirection.front;
      });
    });
  }
}
