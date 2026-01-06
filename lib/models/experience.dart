import 'package:cloud_firestore/cloud_firestore.dart';

class Experience {
  final String id;
  final String name;
  final String? category;
  final String? device;
  final String? description;
  final String? logoUrl;
  final bool enabled;
  final String? creatorId;
  final Timestamp? createdAt;
  final Timestamp? lastUpdated;
  final List<Map<String, dynamic>> booths;
  final List<Map<String, dynamic>> collaborators;
  final List<String> collaboratorUids;
  final List<String> collaboratorEmails;

  Experience({
    required this.id,
    required this.name,
    this.category,
    this.device,
    this.description,
    this.logoUrl,
    this.enabled = true,
    this.creatorId,
    this.createdAt,
    this.lastUpdated,
    this.booths = const [],
    this.collaborators = const [],
    this.collaboratorUids = const [],
    this.collaboratorEmails = const [],
  });

  factory Experience.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Experience(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String?,
      device: data['device'] as String?,
      description: data['description'] as String?,
      logoUrl: data['logoUrl'] as String?,
      enabled: data['enabled'] as bool? ?? true,
      creatorId: data['creatorId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      lastUpdated: data['last_updated'] as Timestamp?,
      booths:
          (data['booths'] as List?)
              ?.map((b) => Map<String, dynamic>.from(b as Map))
              .toList() ??
          [],
      collaborators:
          (data['collaborators'] as List?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          [],
      collaboratorUids:
          (data['collaboratorUids'] as List?)
              ?.map((uid) => uid.toString())
              .toList() ??
          [],
      collaboratorEmails:
          (data['collaboratorEmails'] as List?)
              ?.map((email) => email.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'device': device,
      'description': description,
      'logoUrl': logoUrl,
      'enabled': enabled,
      'creatorId': creatorId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'last_updated': lastUpdated ?? FieldValue.serverTimestamp(),
      'booths': booths,
      'collaborators': collaborators,
      'collaboratorUids': collaboratorUids,
      'collaboratorEmails': collaboratorEmails,
    };
  }
}
