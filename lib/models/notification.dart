import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String? message;
  final String? recipientUid;
  final String? recipientEmail;
  final String? experienceId;
  final String? experienceName;
  final String? senderName;
  final String? senderEmail;
  final String? status;
  final Timestamp createdAt;

  AppNotification({
    required this.id,
    required this.type,
    this.message,
    this.recipientUid,
    this.recipientEmail,
    this.experienceId,
    this.experienceName,
    this.senderName,
    this.senderEmail,
    this.status,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      type: data['type'] as String? ?? '',
      message: data['message'] as String?,
      recipientUid: data['recipientUid'] as String?,
      recipientEmail: data['recipientEmail'] as String?,
      experienceId: data['experienceId'] as String?,
      experienceName: data['experienceName'] as String?,
      senderName: data['senderName'] as String?,
      senderEmail: data['senderEmail'] as String?,
      status: data['status'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'message': message,
      'recipientUid': recipientUid,
      'recipientEmail': recipientEmail,
      'experienceId': experienceId,
      'experienceName': experienceName,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'status': status,
      'createdAt': createdAt,
    };
  }

  bool get isInvite => type == 'invite';
}
