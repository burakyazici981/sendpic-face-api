enum FriendshipStatus { pending, accepted, rejected, blocked }

class FriendshipModel {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  FriendshipModel({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FriendshipModel.fromJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  factory FriendshipModel.fromSupabaseJson(Map<String, dynamic> json) {
    return FriendshipModel(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: _parseStatus(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static FriendshipStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return FriendshipStatus.pending;
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'rejected':
        return FriendshipStatus.rejected;
      case 'blocked':
        return FriendshipStatus.blocked;
      default:
        throw ArgumentError('Unknown friendship status: $status');
    }
  }

  FriendshipModel copyWith({
    String? id,
    String? requesterId,
    String? addresseeId,
    FriendshipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendshipModel(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      addresseeId: addresseeId ?? this.addresseeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Accept friendship request
  FriendshipModel accept() {
    return copyWith(
      status: FriendshipStatus.accepted,
      updatedAt: DateTime.now(),
    );
  }

  // Reject friendship request
  FriendshipModel reject() {
    return copyWith(
      status: FriendshipStatus.rejected,
      updatedAt: DateTime.now(),
    );
  }

  // Block user
  FriendshipModel block() {
    return copyWith(
      status: FriendshipStatus.blocked,
      updatedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'FriendshipModel(id: $id, requesterId: $requesterId, addresseeId: $addresseeId, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendshipModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}