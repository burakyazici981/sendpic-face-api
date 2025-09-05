enum TransactionType { earned, spent, purchased }

class TokenModel {
  final String id;
  final String userId;
  final int amount;
  final TransactionType transactionType;
  final DateTime createdAt;

  TokenModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.transactionType,
    required this.createdAt,
  });

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: json['amount'] as int,
      transactionType: _parseTransactionType(json['transaction_type'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'transaction_type': transactionType.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static TransactionType _parseTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'earned':
        return TransactionType.earned;
      case 'spent':
        return TransactionType.spent;
      case 'purchased':
        return TransactionType.purchased;
      default:
        throw ArgumentError('Unknown transaction type: $type');
    }
  }

  TokenModel copyWith({
    String? id,
    String? userId,
    int? amount,
    TransactionType? transactionType,
    DateTime? createdAt,
  }) {
    return TokenModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TokenModel(id: $id, userId: $userId, amount: $amount, type: $transactionType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TokenModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
