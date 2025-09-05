import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../data/services/profile_image_service.dart';
import '../providers/auth_provider.dart';

class ProfileImagePicker extends StatefulWidget {
  final String? currentImageUrl;
  final double size;
  final bool isEditable;
  final VoidCallback? onImageChanged;
  
  const ProfileImagePicker({
    super.key,
    this.currentImageUrl,
    this.size = 120,
    this.isEditable = true,
    this.onImageChanged,
  });

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  final ProfileImageService _profileImageService = ProfileImageService();
  bool _isUploading = false;
  String? _currentImageUrl;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.currentImageUrl;
  }

  @override
  void didUpdateWidget(ProfileImagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentImageUrl != oldWidget.currentImageUrl) {
      setState(() {
        _currentImageUrl = widget.currentImageUrl;
        _selectedImage = null;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!widget.isEditable) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Profile Picture',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  if (_currentImageUrl != null)
                    _buildSourceOption(
                      icon: Icons.delete,
                      label: 'Remove',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        _removeImage();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: (color ?? Theme.of(context).primaryColor).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: color ?? Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: color ?? Theme.of(context).primaryColor,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color ?? Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isUploading = true;
      });

      XFile? image;
      if (source == ImageSource.camera) {
        image = await _profileImageService.pickImageFromCamera();
      } else {
        image = await _profileImageService.pickImageFromGallery();
      }

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        
        await _uploadImage(image);
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadImage(XFile image) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final imageUrl = await _profileImageService.uploadProfileImage(
        userId: userId,
        imageFile: image,
      );

      if (imageUrl != null) {
        setState(() {
          _currentImageUrl = imageUrl;
          _selectedImage = null;
        });
        
        // Update auth provider
        await authProvider.updateProfile(profileImageUrl: imageUrl);
        
        widget.onImageChanged?.call();
        
        _showSuccessSnackBar('Profile picture updated successfully!');
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading image: $e');
      setState(() {
        _selectedImage = null;
      });
    }
  }

  Future<void> _removeImage() async {
    try {
      setState(() {
        _isUploading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;
      
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final success = await _profileImageService.deleteProfileImage(userId);

      if (success) {
        setState(() {
          _currentImageUrl = null;
          _selectedImage = null;
        });
        
        // Update auth provider
        await authProvider.updateProfile(profileImageUrl: null);
        
        widget.onImageChanged?.call();
        
        _showSuccessSnackBar('Profile picture removed successfully!');
      } else {
        throw Exception('Failed to remove image');
      }
    } catch (e) {
      _showErrorSnackBar('Error removing image: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_selectedImage != null) {
      // Show selected image preview
      if (kIsWeb) {
        return FutureBuilder<Uint8List>(
          future: _selectedImage!.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                width: widget.size,
                height: widget.size,
                fit: BoxFit.cover,
              );
            }
            return const CircularProgressIndicator();
          },
        );
      } else {
        return Image.file(
          File(_selectedImage!.path),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
        );
      }
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      // Show current profile image
      return Image.network(
        _currentImageUrl!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    } else {
      // Show placeholder
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(widget.size / 2),
      ),
      child: Icon(
        Icons.person,
        size: widget.size * 0.6,
        color: Theme.of(context).primaryColor.withOpacity(0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isEditable ? _showImageSourceDialog : null,
      child: Stack(
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.size / 2),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.size / 2),
              child: _buildImageWidget(),
            ),
          ),
          if (widget.isEditable)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: widget.size * 0.25,
                height: widget.size * 0.25,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(widget.size * 0.125),
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: widget.size * 0.12,
                ),
              ),
            ),
          if (_isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(widget.size / 2),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Simple profile avatar widget for displaying profile images
class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String? name;
  
  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(context);
                },
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: name != null && name!.isNotEmpty
          ? Center(
              child: Text(
                name!.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            )
          : Icon(
              Icons.person,
              size: size * 0.6,
              color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
    );
  }
}