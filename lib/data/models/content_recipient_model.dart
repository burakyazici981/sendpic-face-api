class ContentRecipientModel {
  final String id;
  final String contentId;
  final String recipientId;
  final String senderId;
  final String mediaUrl;
  final bool isLiked;
  final bool friendRequested;
  final bool isViewed;
  final int tokensUsed;
  final DateTime receivedAt;
  final DateTime? viewedAt;
  final Map<String, dynamic>? postInfo; // For joined post data

  ContentRecipientModel({
    required this.id,
    required this.contentId,
    required this.recipientId,
    required this.senderId,
    required this.mediaUrl,
    required this.isLiked,
    required this.friendRequested,
    required this.isViewed,
    required this.tokensUsed,
    required this.receivedAt,
    this.viewedAt,
    this.postInfo,
  });

  factory ContentRecipientModel.fromJson(Map<String, dynamic> json) {
    return ContentRecipientModel(
      id: json['id'] as String,
      contentId: json['content_id'] as String,
      recipientId: json['recipient_id'] as String,
      senderId: json['sender_id'] as String,
      mediaUrl: json['media_url'] as String,
      isLiked: (json['is_liked'] as int?) == 1,
      friendRequested: (json['friend_requested'] as int?) == 1,
      isViewed: (json['is_viewed'] as int?) == 1,
      tokensUsed: json['tokens_used'] as int? ?? 0,
      receivedAt: DateTime.parse(json['received_at'] as String),
      viewedAt: json['viewed_at'] != null 
          ? DateTime.parse(json['viewed_at'] as String) 
          : null,
    );
  }

  // Factory constructor for Supabase data
  factory ContentRecipientModel.fromSupabaseJson(Map<String, dynamic> json) {
    final postData = json['posts'] as Map<String, dynamic>?;
    return ContentRecipientModel(
      id: json['id'] as String,
      contentId: json['content_id'] as String,
      recipientId: json['recipient_id'] as String,
      senderId: json['sender_id'] as String,
      mediaUrl: postData?['content_url'] as String? ?? '',
      isLiked: json['is_liked'] as bool? ?? false,
      friendRequested: json['friend_requested'] as bool? ?? false,
      isViewed: json['is_viewed'] as bool? ?? false,
      tokensUsed: json['tokens_used'] as int? ?? 0,
      receivedAt: DateTime.parse(json['created_at'] as String),
      viewedAt: json['viewed_at'] != null 
          ? DateTime.parse(json['viewed_at'] as String) 
          : null,
      postInfo: postData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'recipient_id': recipientId,
      'sender_id': senderId,
      'media_url': mediaUrl,
      'is_liked': isLiked ? 1 : 0,
      'friend_requested': friendRequested ? 1 : 0,
      'is_viewed': isViewed ? 1 : 0,
      'tokens_used': tokensUsed,
      'received_at': receivedAt.toIso8601String(),
      'viewed_at': viewedAt?.toIso8601String(),
    };
  }

  // For Supabase format
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'content_id': contentId,
      'recipient_id': recipientId,
      'sender_id': senderId,
      'is_liked': isLiked,
      'friend_requested': friendRequested,
      'is_viewed': isViewed,
      'tokens_used': tokensUsed,
      'created_at': receivedAt.toIso8601String(),
      'viewed_at': viewedAt?.toIso8601String(),
    };
  }

  ContentRecipientModel copyWith({
    String? id,
    String? contentId,
    String? recipientId,
    String? senderId,
    String? mediaUrl,
    bool? isLiked,
    bool? friendRequested,
    bool? isViewed,
    int? tokensUsed,
    DateTime? receivedAt,
    DateTime? viewedAt,
    Map<String, dynamic>? postInfo,
  }) {
    return ContentRecipientModel(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      recipientId: recipientId ?? this.recipientId,
      senderId: senderId ?? this.senderId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isLiked: isLiked ?? this.isLiked,
      friendRequested: friendRequested ?? this.friendRequested,
      isViewed: isViewed ?? this.isViewed,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      receivedAt: receivedAt ?? this.receivedAt,
      viewedAt: viewedAt ?? this.viewedAt,
      postInfo: postInfo ?? this.postInfo,
    );
  }

  // Mark content as viewed (Snapchat-like one-time view)
  ContentRecipientModel markAsViewed() {
    return copyWith(
      isViewed: true,
      viewedAt: DateTime.now(),
    );
  }

  // Check if content should be auto-deleted (viewed content)
  bool get shouldBeDeleted => isViewed && viewedAt != null;

  @override
  String toString() {
    return 'ContentRecipientModel(id: $id, contentId: $contentId, recipientId: $recipientId, isViewed: $isViewed)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentRecipientModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}