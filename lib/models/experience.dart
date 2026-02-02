import 'package:cloud_firestore/cloud_firestore.dart';

class Experience {
  final String id;
  final String name;
  final String? category;
  final String? device;
  final String? description;
  final String? logoUrl;
  final String? imageUrl;
  final bool enabled;
  final String? managerId;
  final Map<String, dynamic>? owner;
  final Timestamp? createdAt;
  final Timestamp? lastUpdated;
  final List<Map<String, dynamic>> booths;
  final List<Map<String, dynamic>> collaborators;

  Experience({
    required this.id,
    required this.name,
    this.category,
    this.device,
    this.description,
    this.logoUrl,
    this.enabled = true,
    this.managerId,
    this.owner,
    this.createdAt,
    this.lastUpdated,
    this.booths = const [],
    this.collaborators = const [],
    this.imageUrl,
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
      managerId: data['managerId'] as String?,
      owner: data['owner'] as Map<String, dynamic>?,
      createdAt: data['createdAt'] as Timestamp?,
      lastUpdated: (data['last_updated'] ?? data['lastUpdated']) as Timestamp?,
      imageUrl: data['imageUrl'] as String?,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'enabled': enabled,
      'managerId': managerId,
      'owner': owner,
      'booths': booths,
      'collaborators': collaborators,
      'imageUrl': imageUrl,
      // Store using snake_case to match collection docs
      'last_updated': lastUpdated ?? FieldValue.serverTimestamp(),
    };
  }

  Experience copyWith({
    String? id,
    String? name,
    String? category,
    String? device,
    String? description,
    String? logoUrl,
    bool? enabled,
    String? managerId,
    Map<String, dynamic>? owner,
    Timestamp? createdAt,
    Timestamp? lastUpdated,
    List<Map<String, dynamic>>? booths,
    List<Map<String, dynamic>>? collaborators,
    String? imageUrl,
  }) {
    return Experience(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      device: device ?? this.device,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      enabled: enabled ?? this.enabled,
      managerId: managerId ?? this.managerId,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      booths: booths ?? this.booths,
      collaborators: collaborators ?? this.collaborators,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
