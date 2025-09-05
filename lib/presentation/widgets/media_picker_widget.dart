import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/media_provider.dart';
import '../providers/locale_provider.dart';

class MediaPickerWidget extends StatelessWidget {
  final Function(String mediaUrl, MediaType mediaType)? onMediaSelected;
  final bool showVideoOptions;
  final bool showProfileOption;
  
  const MediaPickerWidget({
    super.key,
    this.onMediaSelected,
    this.showVideoOptions = true,
    this.showProfileOption = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<MediaProvider, LocaleProvider>(
      builder: (context, mediaProvider, localeProvider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mediaProvider.isLoading)
              _buildLoadingWidget(context, mediaProvider, localeProvider)
            else
              _buildPickerOptions(context, mediaProvider, localeProvider),
            
            if (mediaProvider.errorMessage != null)
              _buildErrorWidget(context, mediaProvider, localeProvider),
          ],
        );
      },
    );
  }
  
  Widget _buildLoadingWidget(
    BuildContext context, 
    MediaProvider mediaProvider, 
    LocaleProvider localeProvider
  ) {
    String statusText;
    switch (mediaProvider.status) {
      case MediaStatus.picking:
        statusText = localeProvider.isEnglish ? 'Selecting media...' : 'Medya seçiliyor...';
        break;
      case MediaStatus.processing:
        statusText = localeProvider.isEnglish ? 'Processing...' : 'İşleniyor...';
        break;
      case MediaStatus.uploading:
        statusText = localeProvider.isEnglish ? 'Uploading...' : 'Yükleniyor...';
        break;
      default:
        statusText = localeProvider.isEnglish ? 'Loading...' : 'Yükleniyor...';
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircularProgressIndicator(
            value: mediaProvider.status == MediaStatus.uploading 
                ? mediaProvider.uploadProgress 
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (mediaProvider.status == MediaStatus.uploading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${(mediaProvider.uploadProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPickerOptions(
    BuildContext context, 
    MediaProvider mediaProvider, 
    LocaleProvider localeProvider
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            localeProvider.isEnglish ? 'Select Media' : 'Medya Seç',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Photo options
          Row(
            children: [
              Expanded(
                child: _buildOptionCard(
                  context,
                  icon: Icons.camera_alt,
                  title: localeProvider.isEnglish ? 'Take Photo' : 'Fotoğraf Çek',
                  subtitle: localeProvider.isEnglish ? 'Use camera' : 'Kamera kullan',
                  onTap: () => _handleMediaSelection(
                    context, 
                    mediaProvider, 
                    () => mediaProvider.takePhotoWithCamera()
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOptionCard(
                  context,
                  icon: Icons.photo_library,
                  title: localeProvider.isEnglish ? 'Gallery' : 'Galeri',
                  subtitle: localeProvider.isEnglish ? 'Choose photo' : 'Fotoğraf seç',
                  onTap: () => _handleMediaSelection(
                    context, 
                    mediaProvider, 
                    () => mediaProvider.pickImageFromGallery()
                  ),
                ),
              ),
            ],
          ),
          
          if (showVideoOptions) ...
          [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    context,
                    icon: Icons.videocam,
                    title: localeProvider.isEnglish ? 'Record Video' : 'Video Kaydet',
                    subtitle: localeProvider.isEnglish ? 'Use camera' : 'Kamera kullan',
                    onTap: () => _handleMediaSelection(
                      context, 
                      mediaProvider, 
                      () => mediaProvider.recordVideoWithCamera()
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOptionCard(
                    context,
                    icon: Icons.video_library,
                    title: localeProvider.isEnglish ? 'Video Gallery' : 'Video Galeri',
                    subtitle: localeProvider.isEnglish ? 'Choose video' : 'Video seç',
                    onTap: () => _handleMediaSelection(
                      context, 
                      mediaProvider, 
                      () => mediaProvider.pickVideoFromGallery()
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorWidget(
    BuildContext context, 
    MediaProvider mediaProvider, 
    LocaleProvider localeProvider
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mediaProvider.errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => mediaProvider.clearError(),
            color: Colors.red.shade700,
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleMediaSelection(
    BuildContext context,
    MediaProvider mediaProvider,
    Future<String?> Function() mediaFunction,
  ) async {
    try {
      final mediaUrl = await mediaFunction();
      
      if (mediaUrl != null && onMediaSelected != null) {
        onMediaSelected!(
          mediaUrl, 
          mediaProvider.currentMediaType ?? MediaType.photo
        );
      }
    } catch (e) {
      // Error is handled by the provider
    }
  }
}

class MediaPreviewWidget extends StatelessWidget {
  final String mediaUrl;
  final MediaType mediaType;
  final bool showActions;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  
  const MediaPreviewWidget({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.showActions = true,
    this.onDelete,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Card(
          elevation: 4,
          child: Column(
            children: [
              // Media display
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey.shade200,
                ),
                child: mediaType == MediaType.photo
                    ? Image.network(
                        mediaUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            color: Colors.black12,
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Video thumbnail would go here
                        ],
                      ),
              ),
              
              if (showActions)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (onShare != null)
                        TextButton.icon(
                          onPressed: onShare,
                          icon: const Icon(Icons.share),
                          label: Text(
                            localeProvider.isEnglish ? 'Share' : 'Paylaş',
                          ),
                        ),
                      if (onDelete != null)
                        TextButton.icon(
                          onPressed: onDelete,
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: Text(
                            localeProvider.isEnglish ? 'Delete' : 'Sil',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class MediaUploadButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isCompact;
  
  const MediaUploadButton({
    super.key,
    this.onPressed,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        if (isCompact) {
          return IconButton(
            onPressed: onPressed,
            icon: const Icon(Icons.add_photo_alternate),
            tooltip: localeProvider.isEnglish ? 'Add Media' : 'Medya Ekle',
          );
        }
        
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(
            localeProvider.isEnglish ? 'Add Media' : 'Medya Ekle',
          ),
        );
      },
    );
  }
}