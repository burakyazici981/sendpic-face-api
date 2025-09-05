enum MediaType { image, video }

class ContentModel {
  final String id;
  final String senderId;
  final String mediaUrl;
  final MediaType mediaType;
  final String? caption;
  final String? thumbnailUrl;
  final bool isPublic;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? senderInfo; // For joined user data

  ContentModel({
    required this.id,
    required this.senderId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.thumbnailUrl,
    this.isPublic = true,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.senderInfo,
  });

  factory ContentModel.fromJson(Map<String, dynamic> json) {
    return ContentModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      mediaUrl: json['media_url'] as String,
      mediaType: _parseMediaType(json['media_type'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Factory constructor for Supabase data
  factory ContentModel.fromSupabaseJson(Map<String, dynamic> json) {
    return ContentModel(
      id: json['id'] as String,
      senderId: json['user_id'] as String, // Note: Supabase uses 'user_id'
      mediaUrl: json['content_url'] as String, // Note: Supabase uses 'content_url'
      mediaType: _parseContentType(json['content_type'] as String),
      caption: json['caption'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      isPublic: json['is_public'] as bool? ?? true,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      senderInfo: json['users'] as Map<String, dynamic>?, // Joined user data
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'media_url': mediaUrl,
      'media_type': mediaType.name,
      'caption': caption,
      'thumbnail_url': thumbnailUrl,
      'is_public': isPublic,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // For Supabase format
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'user_id': senderId,
      'content_url': mediaUrl,
      'content_type': mediaType == MediaType.image ? 'photo' : 'video',
      'caption': caption,
      'thumbnail_url': thumbnailUrl,
      'is_public': isPublic,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static MediaType _parseMediaType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      default:
        throw ArgumentError('Unknown media type: $type');
    }
  }

  static MediaType _parseContentType(String type) {
    switch (type.toLowerCase()) {
      case 'photo':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      default:
        throw ArgumentError('Unknown content type: $type');
    }
  }

  ContentModel copyWith({
    String? id,
    String? senderId,
    String? mediaUrl,
    MediaType? mediaType,
    String? caption,
    String? thumbnailUrl,
    bool? isPublic,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? senderInfo,
  }) {
    return ContentModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isPublic: isPublic ?? this.isPublic,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderInfo: senderInfo ?? this.senderInfo,
    );
  }

  @override
  String toString() {
    return 'ContentModel(id: $id, senderId: $senderId, mediaType: $mediaType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
