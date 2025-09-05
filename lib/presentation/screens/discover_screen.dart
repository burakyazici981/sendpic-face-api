import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/content_provider.dart';
import '../../data/models/content_recipient_model.dart';
import '../widgets/loading_widget.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final PageController _pageController = PageController();
  List<ContentRecipientModel> _unviewedContent = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      await contentProvider.loadUnviewedContent(authProvider.currentUser!.id);
      
      // Get unviewed content
      _unviewedContent = contentProvider.unviewedContent;
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _viewContent(int index) async {
    if (index >= _unviewedContent.length) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      final contentRecipient = _unviewedContent[index];
      
      // Mark as viewed (one-time view)
      await contentProvider.markContentAsViewed(contentRecipient.contentId, authProvider.currentUser!.id);
      
      // Remove from unviewed list
      setState(() {
        _unviewedContent.removeAt(index);
      });
    }
  }

  Future<void> _likeContent(int index) async {
    if (index >= _unviewedContent.length) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      final contentRecipient = _unviewedContent[index];
      final success = await contentProvider.likeContent(contentRecipient.contentId, authProvider.currentUser!.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İçerik beğenildi!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(int index) async {
    if (index >= _unviewedContent.length) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      final contentRecipient = _unviewedContent[index];
      
      // Send friend request
      final success = await contentProvider.sendFriendRequest(
        authProvider.currentUser!.id,
        contentRecipient.senderId,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arkadaş isteği gönderildi!'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arkadaş isteği gönderilemedi'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Keşfet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadContent,
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _unviewedContent.isEmpty
              ? _buildEmptyState()
              : _buildContentViewer(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Henüz görülecek içerik yok',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Yeni içerikler için daha sonra tekrar kontrol edin',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContentViewer() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: _unviewedContent.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            
            // Auto-view content after a short delay
            if (mounted && _currentIndex == index) {
              _viewContent(index);
            }
          },
          itemBuilder: (context, index) {
            return _buildContentItem(index);
          },
        ),
        
        // Action buttons
        Positioned(
          bottom: 100,
          right: 20,
          child: Column(
            children: [
              // Like button
              GestureDetector(
                onTap: () => _likeContent(_currentIndex),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Friend request button
              GestureDetector(
                onTap: () => _sendFriendRequest(_currentIndex),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Page indicator
        if (_unviewedContent.isNotEmpty)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_unviewedContent.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContentItem(int index) {
    if (index >= _unviewedContent.length) return const SizedBox.shrink();
    
    final contentRecipient = _unviewedContent[index];
    
    return GestureDetector(
      onTap: () => _viewContent(index),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          image: contentRecipient.mediaUrl != null
              ? DecorationImage(
                  image: NetworkImage(contentRecipient.mediaUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: contentRecipient.mediaUrl == null
            ? Center(
                child: Text(
                  'Medya İçeriği',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Medya İçeriği',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Tek seferlik görüntüleme',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}