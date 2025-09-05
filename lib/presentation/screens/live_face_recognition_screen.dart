import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/face_recognition_provider.dart';
import '../providers/camera_provider.dart';
import '../../core/theme/app_theme.dart';

class LiveFaceRecognitionScreen extends StatefulWidget {
  const LiveFaceRecognitionScreen({super.key});

  @override
  State<LiveFaceRecognitionScreen> createState() => _LiveFaceRecognitionScreenState();
}

class _LiveFaceRecognitionScreenState extends State<LiveFaceRecognitionScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Kamera başlatılıyor...';
  Map<String, dynamic>? _lastResult;

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
          _statusMessage = 'Kameraya bakın ve yüzünüzü çerçeveye alın';
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

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Yüz analiz ediliyor...';
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      final File imageFile = File(image.path);
      
      // Yüz tanıma işlemi
      final faceService = context.read<FaceRecognitionProvider>();
      await faceService.recognizeFaces(imageFile);
      
      final result = faceService.lastResult;
      if (result != null) {
        setState(() {
          _lastResult = result;
          _statusMessage = 'Analiz tamamlandı';
        });
      } else {
        setState(() {
          _statusMessage = 'Yüz tespit edilemedi';
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
        title: const Text('Canlı Yüz Tanıma'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Kamera önizleme
          Expanded(
            flex: 3,
            child: _buildCameraPreview(),
          ),
          
          // Durum mesajı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          // Sonuçlar
          if (_lastResult != null) 
            Expanded(
              flex: 2,
              child: _buildResults(),
            ),
        ],
      ),
      floatingActionButton: _buildCaptureButton(),
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
                color: _isProcessing ? Colors.red : Colors.green,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.face,
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
                    'Yüz analiz ediliyor...',
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

  Widget _buildCaptureButton() {
    return FloatingActionButton(
      onPressed: _isProcessing ? null : _captureAndProcess,
      backgroundColor: _isProcessing ? Colors.grey : AppTheme.primaryColor,
      child: Icon(
        _isProcessing ? Icons.hourglass_empty : Icons.camera_alt,
        color: Colors.white,
      ),
    );
  }

  Widget _buildResults() {
    if (_lastResult == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kimlik Tespiti Sonuçları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Temel bilgiler
          _buildResultCard(
            'Tespit Edilen Yüzler',
            '${_lastResult!['faces_detected'] ?? 0}',
            Icons.face,
            Colors.blue,
          ),
          
          const SizedBox(height: 8),
          
          _buildResultCard(
            'İşlem Süresi',
            '${_lastResult!['processing_time']?.toStringAsFixed(2) ?? '0'}s',
            Icons.timer,
            Colors.orange,
          ),
          
          const SizedBox(height: 8),
          
          _buildResultCard(
            'Güven Skoru',
            '${(_lastResult!['overall_risk_score'] ?? 0.0).toStringAsFixed(2)}',
            Icons.security,
            Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          // Tanınan yüzler
          if (_lastResult!['faces_analyzed'] != null && 
              (_lastResult!['faces_analyzed'] as List).isNotEmpty)
            _buildRecognizedFaces(),
        ],
      ),
    );
  }

  Widget _buildResultCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecognizedFaces() {
    final faces = _lastResult!['faces_analyzed'] as List;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tanınan Yüzler',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...faces.map((face) => Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        face['name'] ?? 'Bilinmeyen',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Güven: ${(face['confidence'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (face['is_spoof'] == true)
                  const Icon(Icons.warning, color: Colors.red),
              ],
            ),
          ),
        )),
      ],
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canlı Yüz Tanıma Ayarları'),
        content: Consumer<FaceRecognitionProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Otomatik Yakalama'),
                  value: provider.settings['auto_capture'] ?? false,
                  onChanged: (value) => provider.updateSetting('auto_capture', value),
                ),
                SwitchListTile(
                  title: const Text('Sesli Uyarı'),
                  value: provider.settings['sound_alert'] ?? true,
                  onChanged: (value) => provider.updateSetting('sound_alert', value),
                ),
                SwitchListTile(
                  title: const Text('Titreşim'),
                  value: provider.settings['vibration'] ?? true,
                  onChanged: (value) => provider.updateSetting('vibration', value),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
