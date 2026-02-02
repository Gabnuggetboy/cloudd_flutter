import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerContentSelection {
  final String id;
  final String managerId;
  final String device;
  final String experienceId;
  final List<String> selectedContents;
  final Timestamp? lastUpdated;

  ManagerContentSelection({
    required this.id,
    required this.managerId,
    required this.device,
    required this.experienceId,
    this.selectedContents = const [],
    this.lastUpdated,
  });

  factory ManagerContentSelection.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ManagerContentSelection(
      id: doc.id,
      managerId: data['managerId'] as String? ?? '',
      device: data['device'] as String? ?? '',
      experienceId: data['experienceId'] as String? ?? '',
      selectedContents:
          (data['selectedContents'] as List?)
              ?.map((c) => c.toString())
              .toList() ??
          [],
      lastUpdated: data['lastUpdated'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'managerId': managerId,
      'device': device,
      'experienceId': experienceId,
      'selectedContents': selectedContents,
      'lastUpdated': lastUpdated ?? FieldValue.serverTimestamp(),
    };
  }
}
