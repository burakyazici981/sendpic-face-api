import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';
import '../../providers/content_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/face_recognition_provider.dart';
import '../face_recognition_screen.dart';
import 'web_home_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CameraProvider>().initializeCamera();
      
      final authProvider = context.read<AuthProvider>();
      final contentProvider = context.read<ContentProvider>();
      
      if (authProvider.currentUser != null) {
        contentProvider.loadTokenBalance(authProvider.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Web platformunda özel ana sayfa göster
    if (kIsWeb) {
      return const WebHomeScreen();
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          return Stack(
            children: [
              // Camera Preview
              if (cameraProvider.isInitialized)
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: cameraProvider.controller!.value.aspectRatio,
                    child: cameraProvider.controller!.buildPreview(),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              
              // Top Controls
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Flash Toggle
                    if (cameraProvider.hasFlash)
                      IconButton(
                        onPressed: cameraProvider.toggleFlash,
                        icon: Icon(
                          cameraProvider.isFlashOn
                              ? Icons.flash_on
                              : Icons.flash_off,
                          color: Colors.white,
                          size: 28,
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                    
                    // Token Balance
                    Consumer<ContentProvider>(
                      builder: (context, contentProvider, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.monetization_on,
                                color: Colors.yellow,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                contentProvider.tokenBalance.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    // Face Recognition Button
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FaceRecognitionScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.face,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    
                    // Switch Camera
                    IconButton(
                      onPressed: cameraProvider.switchCamera,
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom Controls
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Capture Button
                    GestureDetector(
                      onTap: () => cameraProvider.capturePhoto(),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: cameraProvider.status == CameraStatus.capturing
                            ? const CircularProgressIndicator(
                                color: Colors.black,
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 32,
                                color: Colors.black,
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Send Options
                    const Text(
                      'Gönderim Seçenekleri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Recipient Options
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildRecipientOption('6', '1'),
                        _buildRecipientOption('10', '2'),
                        _buildRecipientOption('100', '10'),
                        _buildRecipientOption('1000', '50'),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Error Message
              if (cameraProvider.errorMessage != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cameraProvider.errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecipientOption(String count, String tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '$tokens jeton',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
