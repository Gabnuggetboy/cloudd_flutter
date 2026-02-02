import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/models/notification.dart';

class ExperienceService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _experiences => _db.collection('Experiences');
  CollectionReference get _notifications => _db.collection('Notifications');

  String get _uid => _auth.currentUser!.uid;

  // CRUD for Experiences

  Future<String> createExperience({
    required String name,
    String? category,
    String? imageUrl,
    List<Map<String, dynamic>> initialBooths = const [],
  }) async {
    final docRef = _experiences.doc();

    final experience = Experience(
      id: docRef.id,
      name: name,
      category: category,
      imageUrl: imageUrl,
      enabled: true,
      managerId: _uid,
      owner: {'uid': _uid, 'email': _auth.currentUser?.email?.toLowerCase()},
      booths: initialBooths,
      collaborators: [],
      lastUpdated: Timestamp.now(),
    );

    await docRef.set(experience.toMap());
    return docRef.id;
  }

  Future<void> updateExperience(String id, Experience experience) async {
    await _experiences.doc(id).update({
      ...experience.toMap(),
      'last_updated': Timestamp.now(),
    });
  }

  Future<void> updateExperiencePartial(
    String id,
    Map<String, dynamic> data,
  ) async {
    data['last_updated'] = Timestamp.now();
    await _experiences.doc(id).update(data);
  }

  Future<void> deleteExperience(String id) async {
    final exp = await getExperience(id);
    if (exp == null) throw Exception('Experience not found');
    final ownerUid = exp.owner?['uid'] as String?;
    if (ownerUid != _uid) throw Exception('Only owner can delete');

    // Delete all saved content selections for this experience
    final selectionsRef = _experiences
        .doc(id)
        .collection('ManagerContentSelections');
    final selectionsDocs = await selectionsRef.get();
    for (final doc in selectionsDocs.docs) {
      await doc.reference.delete();
    }

    // Delete the experience itself
    await _experiences.doc(id).delete();
  }

  Future<String?> uploadExperienceImage(String experienceId, File image) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
        _uniqueImagePath(experienceId),
      );

      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Image upload failed: $e');
      return null;
    }
  }

  String _uniqueImagePath(String experienceId) {
    final safeId = experienceId.isNotEmpty ? experienceId : 'exp';
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32);
    // Include both a timestamp and random component to avoid overwriting prior uploads
    // Use braces so the analyzer doesn't read `$now_` as a single identifier
    return 'experience_images/${safeId}_${now}_$rand.jpg';
  }

  Future<void> inviteCollaborators({
    required String experienceId,
    required List<Map<String, dynamic>> newInvitees, // [{uid, email}]
    required String experienceName,
  }) async {
    final expRef = _experiences.doc(experienceId);
    final currentUserEmail =
        _auth.currentUser?.email?.toLowerCase() ?? 'unknown';

    // First, get the current experience data
    final snapshot = await expRef.get();
    if (!snapshot.exists) throw Exception('Experience not found');

    final experience = Experience.fromDoc(snapshot);
    final ownerEmail = (experience.owner?['email'] as String?)?.toLowerCase();

    final currentCollabs = List<Map<String, dynamic>>.from(
      experience.collaborators,
    );

    // Create notifications and update collaborators list
    for (final invitee in newInvitees) {
      final email = (invitee['email'] as String).toLowerCase().trim();
      final uid = invitee['uid'] as String?;

      // Don't allow inviting the owner
      if (ownerEmail != null && email == ownerEmail) continue;

      // Check if already invited or accepted
      final alreadyExists = currentCollabs.any(
        (c) => (c['email'] as String?)?.toLowerCase() == email,
      );
      if (alreadyExists) continue;

      currentCollabs.add({
        'email': email,
        'uid': uid,
        'status': 'pending',
        'invitedBy': currentUserEmail,
        'invitedAt': Timestamp.now(),
      });

      // Create notification
      final notif = AppNotification(
        id: '',
        type: 'invite',
        recipientEmail: email,
        recipientUid: uid,
        experienceId: experienceId,
        experienceName: experienceName,
        senderEmail: currentUserEmail,
        status: 'unread',
        createdAt: Timestamp.now(),
      );

      await _notifications.doc().set(notif.toMap());
    }

    // Update experience with new collaborators
    await expRef.update({
      'collaborators': currentCollabs,
      'last_updated': Timestamp.now(),
    });
  }

  Future<List<Map<String, dynamic>>> searchManagersForInvite(
    String query,
  ) async {
    if (query.isEmpty) return [];

    final end = '$query\uf8ff';
    final currentUid = _auth.currentUser?.uid;

    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'Manager')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThan: end)
        .limit(10)
        .get();

    return snap.docs
        .where((doc) => doc.id != currentUid)
        .map((doc) => {'uid': doc.id, 'email': doc['email'] as String})
        .toList();
  }

  Future<Experience?> getExperience(String id) async {
    final doc = await _experiences.doc(id).get();
    return doc.exists ? Experience.fromDoc(doc) : null;
  }

  /// Accept a collaborator invitation for an experience
  Future<void> acceptCollaboratorInvite(String experienceId) async {
    final userEmail = _auth.currentUser?.email?.toLowerCase();
    final userUid = _auth.currentUser?.uid;
    if (userEmail == null || userUid == null) {
      throw Exception('User not authenticated');
    }

    final expRef = _experiences.doc(experienceId);
    final expSnap = await expRef.get();
    if (!expSnap.exists) throw Exception('Experience not found');

    final experience = Experience.fromDoc(expSnap);
    final collaborators = List<Map<String, dynamic>>.from(
      experience.collaborators,
    );

    // Update status to accepted
    bool updated = false;
    for (var c in collaborators) {
      final cEmail = (c['email'] as String?)?.toLowerCase();
      if (cEmail == userEmail && c['status'] == 'pending') {
        c['status'] = 'accepted';
        c['uid'] = userUid;
        c['acceptedAt'] = Timestamp.now();
        updated = true;
      }
    }

    if (!updated) return;

    await expRef.update({
      'collaborators': collaborators,
      'last_updated': Timestamp.now(),
    });
  }

  /// Decline a collaborator invitation for an experience
  Future<void> declineCollaboratorInvite(String experienceId) async {
    final userEmail = _auth.currentUser?.email?.toLowerCase();
    if (userEmail == null) throw Exception('User not authenticated');

    final expRef = _experiences.doc(experienceId);
    final expSnap = await expRef.get();
    if (!expSnap.exists) return;

    final experience = Experience.fromDoc(expSnap);
    final collaborators = List<Map<String, dynamic>>.from(
      experience.collaborators,
    );

    // Remove pending invite
    collaborators.removeWhere(
      (c) =>
          (c['email'] as String?)?.toLowerCase() == userEmail &&
          (c['status'] as String?) == 'pending',
    );

    await expRef.update({
      'collaborators': collaborators,
      'last_updated': Timestamp.now(),
    });
  }
}
