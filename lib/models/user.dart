import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String role;
  final Timestamp? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    this.role = 'User',
    this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'User',
      createdAt: data['created_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  bool get isManager => role == 'Manager';
  bool get isUser => role == 'User';
}
