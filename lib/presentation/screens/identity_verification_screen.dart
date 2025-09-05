import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/face_recognition_provider.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';

class IdentityVerificationScreen extends StatefulWidget {
  final UserModel user;
  
  const IdentityVerificationScreen({
    super.key, 
    required this.user,
  });

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isVerified = false;
  String _statusMessage = 'Kamera başlatılıyor...';
  double _verificationScore = 0.0;
  String? _verificationResult;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: false,
        );
        
        await _cameraController!.initialize();
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Yüzünüzü kameraya gösterin ve kimlik doğrulaması yapın';
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

  Future<void> _verifyIdentity() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Kimlik doğrulanıyor...';
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final File liveImageFile = File(image.path);
      
      // Profil resmi ile canlı resmi karşılaştır
      final faceProvider = context.read<FaceRecognitionProvider>();
      final authProvider = context.read<AuthProvider>();
      
      // Kimlik doğrulama işlemi
      final verificationResult = await faceProvider.verifyIdentity(
        liveImageFile, 
        widget.user.profileImageUrl ?? '',
        widget.user.id,
      );
      
      if (verificationResult != null) {
        setState(() {
          _verificationScore = verificationResult['similarity_score'] ?? 0.0;
          _verificationResult = verificationResult['result'];
          _isVerified = verificationResult['is_verified'] ?? false;
          
          if (_isVerified) {
            _statusMessage = 'Kimlik doğrulandı! ✅';
            // Profil durumunu güncelle
            authProvider.updateVerificationStatus(true);
          } else {
            _statusMessage = 'Kimlik doğrulanamadı. Tekrar deneyin.';
          }
        });
      } else {
        setState(() {
          _statusMessage = 'Doğrulama işlemi başarısız';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Hata: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kimlik Doğrulama'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Kullanıcı bilgileri
          _buildUserInfo(),
          
          // Kamera önizleme
          Expanded(
            flex: 3,
            child: _buildCameraPreview(),
          ),
          
          // Durum mesajı
          _buildStatusMessage(),
          
          // Sonuçlar
          if (_verificationResult != null) 
            _buildVerificationResults(),
        ],
      ),
      floatingActionButton: _buildVerifyButton(),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: widget.user.profileImageUrl != null
                ? NetworkImage(widget.user.profileImageUrl!)
                : null,
            child: widget.user.profileImageUrl == null
                ? const Icon(Icons.person, size: 30)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.user.email,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      widget.user.isVerified ? Icons.verified : Icons.pending,
                      color: widget.user.isVerified ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.user.isVerified ? 'Doğrulanmış' : 'Doğrulanmamış',
                      style: TextStyle(
                        color: widget.user.isVerified ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
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
        
        // Yüz çerçevesi
        Center(
          child: Container(
            width: 250,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isProcessing 
                    ? Colors.orange 
                    : _isVerified 
                        ? Colors.green 
                        : Colors.blue,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Icon(
                _isVerified ? Icons.verified : Icons.face,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        ),
        
        // İşlem göstergesi
        if (_isProcessing)
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
                    'Kimlik doğrulanıyor...',
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

  Widget _buildStatusMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: _getStatusColor(),
      child: Text(
        _statusMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (_isVerified) return Colors.green;
    if (_isProcessing) return Colors.orange;
    if (_statusMessage.contains('Hata')) return Colors.red;
    return Colors.blue;
  }

  Widget _buildVerificationResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Benzerlik Skoru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(_verificationScore * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _verificationScore > 0.7 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _verificationScore,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _verificationScore > 0.7 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _isVerified ? Icons.check_circle : Icons.cancel,
                    color: _isVerified ? Colors.green : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isVerified 
                          ? 'Kimlik başarıyla doğrulandı!'
                          : 'Kimlik doğrulanamadı. Lütfen tekrar deneyin.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _isVerified ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return FloatingActionButton.extended(
      onPressed: _isProcessing ? null : _verifyIdentity,
      backgroundColor: _isVerified ? Colors.green : AppTheme.primaryColor,
      icon: Icon(
        _isProcessing 
            ? Icons.hourglass_empty 
            : _isVerified 
                ? Icons.check 
                : Icons.verified_user,
      ),
      label: Text(
        _isProcessing 
            ? 'Doğrulanıyor...' 
            : _isVerified 
                ? 'Doğrulandı' 
                : 'Kimliği Doğrula',
      ),
    );
  }
}
