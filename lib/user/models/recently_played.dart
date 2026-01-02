import 'package:cloud_firestore/cloud_firestore.dart';

class RecentlyPlayed {
  final String id;
  final String userId;
  final String boothName;
  final String device;
  final String experienceId;
  final String experienceName;
  final String? logoUrl;
  final Timestamp timestamp;

  RecentlyPlayed({
    required this.id,
    required this.userId,
    required this.boothName,
    required this.device,
    required this.experienceId,
    required this.experienceName,
    this.logoUrl,
    required this.timestamp,
  });

  factory RecentlyPlayed.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    // Only use the standardized `timestamp` field.
    final ts = (data['timestamp'] as Timestamp?) ?? Timestamp.now();

    return RecentlyPlayed(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      boothName: data['boothName'] as String? ?? '',
      device: data['device'] as String? ?? '',
      experienceId: data['experienceId'] as String? ?? '',
      experienceName: data['experienceName'] as String? ?? '',
      logoUrl: (data['logoUrl'] as String?) ?? (data['logo'] as String?),
      timestamp: ts,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'boothName': boothName,
      'device': device,
      'experienceId': experienceId,
      'experienceName': experienceName,
      'logoUrl': logoUrl ?? '',
      'timestamp': timestamp,
    };
  }
}
