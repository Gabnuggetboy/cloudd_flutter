import 'package:cloud_firestore/cloud_firestore.dart';

class Collaborator {
  final String uid;
  final String role;
  final DateTime addedAt;

  Collaborator({required this.uid, required this.role, required this.addedAt});

  factory Collaborator.fromMap(Map<String, dynamic> map) {
    return Collaborator(
      uid: map['uid'],
      role: map['role'],
      addedAt: (map['addedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'role': role, 'addedAt': Timestamp.fromDate(addedAt)};
  }
}
