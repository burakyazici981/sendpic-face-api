import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/face_recognition_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import 'live_face_recognition_screen.dart';
import 'identity_verification_screen.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FaceRecognitionProvider>().testConnection();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yüz Tanıma'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: Consumer<FaceRecognitionProvider>(
        builder: (context, faceProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bağlantı durumu
                _buildConnectionStatus(faceProvider),
                
                const SizedBox(height: 20),
                
                // Resim seçimi
                _buildImageSelection(),
                
                const SizedBox(height: 20),
                
                // Seçilen resim
                if (_selectedImage != null) _buildSelectedImage(),
                
                const SizedBox(height: 20),
                
                // İşlem butonları
                _buildActionButtons(faceProvider),
                
                const SizedBox(height: 20),
                
                // Sonuçlar
                if (faceProvider.lastResult != null) _buildResults(faceProvider),
                
                const SizedBox(height: 20),
                
                // Geçmiş
                _buildHistory(faceProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(FaceRecognitionProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              provider.isConnected ? Icons.check_circle : Icons.error,
              color: provider.isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.isConnected ? 'Bağlantı Başarılı' : 'Bağlantı Hatası',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    provider.isConnected 
                        ? 'Yüz tanıma servisi hazır'
                        : 'Servis bağlantısı kurulamadı',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (!provider.isConnected)
              ElevatedButton(
                onPressed: () => provider.testConnection(),
                child: const Text('Tekrar Dene'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kimlik Tespiti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Kimlik doğrulama butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openIdentityVerification(),
                icon: const Icon(Icons.verified_user),
                label: const Text('Kimlik Doğrulama'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Canlı kamera butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openLiveCamera(),
                icon: const Icon(Icons.videocam),
                label: const Text('Canlı Kamera ile Tespit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Veya Resim Yükle',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Resim Seç'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Yeni butonlar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedImage != null ? () => _detectFaces() : null,
                    icon: const Icon(Icons.face),
                    label: const Text('Yüz Tespit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedImage != null ? () => _recognizeFaces() : null,
                    icon: const Icon(Icons.person_search),
                    label: const Text('Yüz Tanı'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedImage != null ? () => _detectGender() : null,
                    icon: const Icon(Icons.wc),
                    label: const Text('Cinsiyet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedImage != null ? () => _antiSpoofDetection() : null,
                    icon: const Icon(Icons.security),
                    label: const Text('Anti-Spoof'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seçilen Resim',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _selectedImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(FaceRecognitionProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İşlemler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isLoading || _selectedImage == null
                        ? null
                        : () => provider.detectFaces(_selectedImage!),
                    icon: provider.isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.face),
                    label: const Text('Yüz Tespit Et'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isLoading || _selectedImage == null
                        ? null
                        : () => provider.recognizeFaces(_selectedImage!),
                    icon: provider.isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.face_retouching_natural),
                    label: const Text('Yüz Tanı'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(FaceRecognitionProvider provider) {
    final result = provider.lastResult!;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sonuçlar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Temel bilgiler
            _buildResultItem('Yüz Sayısı', '${provider.getFaceCount()}'),
            _buildResultItem('İşlem Süresi', '${provider.getProcessingTime().toStringAsFixed(2)}s'),
            _buildResultItem('Risk Skoru', '${provider.getRiskScore().toStringAsFixed(2)}'),
            
            const SizedBox(height: 16),
            
            // Tespit edilen yüzler
            if (provider.getDetectedFaces().isNotEmpty) ...[
              const Text(
                'Tespit Edilen Yüzler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...provider.getDetectedFaces().map((face) => 
                _buildFaceInfo(face, 'Tespit')
              ),
            ],
            
            // Tanınan yüzler
            if (provider.getRecognizedFaces().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tanınan Yüzler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...provider.getRecognizedFaces().map((face) => 
                _buildFaceInfo(face, 'Tanıma')
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceInfo(Map<String, dynamic> face, String type) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$type Bilgileri',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (face['bbox'] != null)
              _buildResultItem('Konum', '${face['bbox']}'),
            if (face['confidence'] != null)
              _buildResultItem('Güven', '${(face['confidence'] * 100).toStringAsFixed(1)}%'),
            if (face['gender'] != null)
              _buildResultItem('Cinsiyet', face['gender']),
            if (face['is_spoof'] != null)
              _buildResultItem('Sahte', face['is_spoof'] ? 'Evet' : 'Hayır'),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(FaceRecognitionProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Geçmiş',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => provider.clearResults(),
                  child: const Text('Temizle'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (provider.recognitionHistory.isEmpty)
              const Text('Henüz işlem yapılmamış')
            else
              ...provider.recognitionHistory.take(5).map((result) => 
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text('${result['faces_detected'] ?? 0} yüz tespit edildi'),
                  subtitle: Text('${result['processing_time']?.toStringAsFixed(2) ?? '0'}s'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        
        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resim başarıyla seçildi!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resim seçme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yüz Tanıma Ayarları'),
        content: Consumer<FaceRecognitionProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Yüz Tanıma'),
                  value: provider.isFaceRecognitionEnabled,
                  onChanged: (value) => provider.updateSetting('enable_face_recognition', value),
                ),
                SwitchListTile(
                  title: const Text('Cinsiyet Tespiti'),
                  value: provider.isGenderDetectionEnabled,
                  onChanged: (value) => provider.updateSetting('enable_gender_detection', value),
                ),
                SwitchListTile(
                  title: const Text('Anti-Spoofing'),
                  value: provider.isAntiSpoofEnabled,
                  onChanged: (value) => provider.updateSetting('enable_anti_spoof', value),
                ),
                SwitchListTile(
                  title: const Text('Otomatik Kaydet'),
                  value: provider.settings['auto_save_results'] ?? true,
                  onChanged: (value) => provider.updateSetting('auto_save_results', value),
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

  void _detectFaces() {
    if (_selectedImage != null) {
      context.read<FaceRecognitionProvider>().detectFaces(_selectedImage!);
    }
  }

  void _recognizeFaces() {
    if (_selectedImage != null) {
      context.read<FaceRecognitionProvider>().recognizeFaces(_selectedImage!);
    }
  }

  void _detectGender() {
    if (_selectedImage != null) {
      context.read<FaceRecognitionProvider>().detectGender(_selectedImage!);
    }
  }

  void _antiSpoofDetection() {
    if (_selectedImage != null) {
      context.read<FaceRecognitionProvider>().antiSpoofDetection(_selectedImage!);
    }
  }

  void _openIdentityVerification() {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce giriş yapın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IdentityVerificationScreen(user: currentUser),
      ),
    );
  }

  void _openLiveCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LiveFaceRecognitionScreen(),
      ),
    );
  }
}
