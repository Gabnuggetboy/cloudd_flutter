import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollaboratorService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  DocumentReference experienceRef(String id) =>
      _db.collection('experiences').doc(id);

  // Add collaborator
  Future<void> addCollaborator({
    required String experienceId,
    required String collaboratorUid,
    String role = 'collaborator',
  }) async {
    final ref = experienceRef(experienceId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;

      final collaborators = List.from(data['collaborators']);

      final alreadyExists = collaborators.any(
        (c) => c['uid'] == collaboratorUid,
      );

      if (alreadyExists) return;

      collaborators.add({
        'uid': collaboratorUid,
        'role': role,
        'addedAt': FieldValue.serverTimestamp(),
      });

      tx.update(ref, {
        'collaborators': collaborators,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });
  }

  // Remove collaborator
  Future<void> removeCollaborator(
    String experienceId,
    String collaboratorUid,
  ) async {
    final ref = experienceRef(experienceId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;

      final collaborators = List.from(data['collaborators'])
        ..removeWhere((c) => c['uid'] == collaboratorUid);

      tx.update(ref, {
        'collaborators': collaborators,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });
  }

  // Change collaborator role
  Future<void> changeRole({
    required String experienceId,
    required String collaboratorUid,
    required String newRole,
  }) async {
    final ref = experienceRef(experienceId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>;

      final collaborators = List<Map<String, dynamic>>.from(
        data['collaborators'],
      );

      for (final c in collaborators) {
        if (c['uid'] == collaboratorUid) {
          c['role'] = newRole;
        }
      }

      tx.update(ref, {
        'collaborators': collaborators,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });
  }

  // Check user role in experience
  Future<String?> getUserRole(String experienceId) async {
    final snap = await experienceRef(experienceId).get();
    final data = snap.data() as Map<String, dynamic>;

    final collaborators = List.from(data['collaborators']);

    final match = collaborators.firstWhere(
      (c) => c['uid'] == _uid,
      orElse: () => null,
    );

    return match?['role'];
  }
}
