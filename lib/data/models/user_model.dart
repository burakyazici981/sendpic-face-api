class UserModel {
  final String id;
  final String email;
  final String name;
  final String? passwordHash;
  final String? gender;
  final int? age;
  final DateTime? birthDate; // Yeni alan
  final String? bio;
  final String? profileImageUrl;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.passwordHash,
    this.gender,
    this.age,
    this.birthDate,
    this.bio,
    this.profileImageUrl,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      passwordHash: json['password_hash'] as String?,
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date'] as String) : null,
      bio: json['bio'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      isVerified: (json['is_verified'] as int?) == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Factory constructor for Supabase data (boolean is_verified)
  factory UserModel.fromSupabaseJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      passwordHash: json['password_hash'] as String?,
      gender: json['gender'] as String?,
      age: json['age'] as int?,
      birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date'] as String) : null,
      bio: json['bio'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'password_hash': passwordHash,
      'gender': gender,
      'age': age,
      'birth_date': birthDate?.toIso8601String(),
      'bio': bio,
      'profile_image_url': profileImageUrl,
      'is_verified': isVerified ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? passwordHash,
    String? gender,
    int? age,
    DateTime? birthDate,
    String? bio,
    String? profileImageUrl,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      passwordHash: passwordHash ?? this.passwordHash,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      birthDate: birthDate ?? this.birthDate,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, name: $name, isVerified: $isVerified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
