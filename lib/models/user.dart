import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';


class AppUser {
  final String uid;
  final String email;
  final String role;
   final String name;
  final Timestamp? dateOfBirth;
  final String? profileImageUrl;
  final Timestamp? createdAt;

  AppUser({
    required this.uid,
    required this.email,
    this.role = 'User',
        this.name = '',
    this.dateOfBirth,
    this.profileImageUrl,
    this.createdAt,
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'User',
      name: data['name'] as String? ?? '',
      dateOfBirth: data['date_of_birth'] as Timestamp?,
      profileImageUrl: data['profile_image_url'] as String?,
      createdAt: data['created_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'name': name, 
      'date_of_birth': dateOfBirth,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

 Future<void> save() async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(toMap());
    debugPrint("Firestore user created: $uid");
  } catch (e) {
    debugPrint("Firestore write failed: $e");
    rethrow;
  }
}

  bool get isManager => role == 'Manager';
  bool get isUser => role == 'User';
}
