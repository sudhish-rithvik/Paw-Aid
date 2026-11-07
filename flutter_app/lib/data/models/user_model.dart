// lib/data/models/user_model.dart
import '../../core/firebase/firebase_constants.dart';

class UserModel {
  final String id; // uid
  final String email;
  final String role; // 'citizen', 'ngo_staff', 'admin'
  final String? displayName; // fullName
  final String? phone; // phoneNumber
  final String accountStatus; // 'active', 'pending', 'suspended', 'rejected'
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    this.phone,
    this.accountStatus = 'active',
    this.fcmToken,
    required this.createdAt,
    this.updatedAt,
  });

  String get uid => id;
  String? get fullName => displayName;
  String? get phoneNumber => phone;

  bool get isCitizen =>
      role.toLowerCase() == FirebaseConstants.roleCitizen ||
      role.toUpperCase() == 'CITIZEN';

  bool get isNgo =>
      role.toLowerCase() == FirebaseConstants.roleNgo ||
      role.toLowerCase() == 'ngo' ||
      role.toUpperCase() == 'NGO';

  bool get isAdmin =>
      role.toLowerCase() == FirebaseConstants.roleAdmin ||
      role.toUpperCase() == 'ADMIN';

  bool get isPending =>
      accountStatus.toLowerCase() == 'pending';

  bool get isActive =>
      accountStatus.toLowerCase() == 'active';

  Map<String, dynamic> toMap() => {
        'id': id,
        'uid': id,
        'email': email,
        'role': role,
        'display_name': displayName,
        'fullName': displayName,
        'phone': phone,
        'phoneNumber': phone,
        'accountStatus': accountStatus,
        'account_status': accountStatus,
        'fcm_token': fcmToken,
        'created_at': createdAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updated_at': (updatedAt ?? createdAt).toIso8601String(),
        'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
      };

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final effectiveId = docId ?? map['uid'] as String? ?? map['id'] as String? ?? '';
    final name = map['fullName'] as String? ?? map['display_name'] as String?;
    final phoneNum = map['phoneNumber'] as String? ?? map['phone'] as String?;
    final status = map['accountStatus'] as String? ??
        map['account_status'] as String? ??
        'active';

    final createdRaw = map['createdAt'] ?? map['created_at'];
    final updatedRaw = map['updatedAt'] ?? map['updated_at'];

    return UserModel(
      id: effectiveId,
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? FirebaseConstants.roleCitizen,
      displayName: name,
      phone: phoneNum,
      accountStatus: status,
      fcmToken: map['fcm_token'] as String? ?? map['fcmToken'] as String?,
      createdAt: createdRaw != null
          ? DateTime.tryParse(createdRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: updatedRaw != null
          ? DateTime.tryParse(updatedRaw.toString())
          : null,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? role,
    String? displayName,
    String? phone,
    String? accountStatus,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      accountStatus: accountStatus ?? this.accountStatus,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
