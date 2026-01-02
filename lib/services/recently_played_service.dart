import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/user/models/recently_played.dart';

class RecentlyPlayedService {
  // Recently played will be a subcollection under the "users" collection
    static CollectionReference _userCol(String userId) =>
      FirebaseFirestore.instance.collection('users').doc(userId).collection('RecentlyPlayed');

  /// Returns empty stream if `userId` is empty
  static Stream<List<RecentlyPlayed>> streamRecentForUser(
    String userId, {
    int limit = 10,
  }) {
    if (userId.isEmpty) return Stream.value([]);

    // Use `timestamp` (server timestamp) and read from the user's subcollection
    return _userCol(userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => RecentlyPlayed.fromDoc(d)).toList(),
        );
  }

  /// Convenience to get current user's recent items stream that uses firebaseauth
  static Stream<List<RecentlyPlayed>> streamCurrentUserRecent({
    int limit = 10,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return streamRecentForUser(uid, limit: limit);
  }

  /// Add a recently played entry for a user
  static Future<void> addRecentlyPlayed({
    required String userId,
    required String device,
    required String boothName,
    required String experienceId,
    required String experienceName,
    String? logoUrl,
  }) async {
    // Create the payload for write or update
    final payload = {
      'userId': userId,
      'device': device,
      'boothName': boothName,
      'experienceId': experienceId,
      'experienceName': experienceName,
      'logoUrl': logoUrl ?? '',
      // Use only `timestamp` (server timestamp)
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      // Try to find an existing entry for this user + booth + experience
        final existing = await _userCol(userId)
          .where('boothName', isEqualTo: boothName)
          .where('experienceId', isEqualTo: experienceId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update the existing document's timestamp and any changed fields
        final docRef = existing.docs.first.reference;
        await docRef.update({
          'timestamp': FieldValue.serverTimestamp(),
          'device': device,
          'experienceName': experienceName,
          'logoUrl': logoUrl ?? '',
        });
      } else {
        // No existing entry — add a new one
        await _userCol(userId).add(payload);
      }
      // Show max 10 recently played content
      await _enforceLimitForUser(userId, max: 10);
    } catch (e) {
      await _userCol(userId).add(payload);
      try {
        await _enforceLimitForUser(userId, max: 10);
      } catch (_) {}
    }
  }

  // To ensure a user doesn't have more than [max] recently-played documents.
  static Future<void> _enforceLimitForUser(
    String userId, {
    int max = 10,
  }) async {
    if (userId.isEmpty) return;

    final snap = await _userCol(userId).orderBy('timestamp', descending: true).get();

    final docs = snap.docs;
    if (docs.length <= max) return;

    final batch = FirebaseFirestore.instance.batch();

    // Documents after index `max - 1` are the oldest because of descending order
    for (var i = max; i < docs.length; i++) {
      batch.delete(docs[i].reference);
    }

    await batch.commit();
  }

  /// Stream raw QuerySnapshot if needed elsewhere
  static Stream<QuerySnapshot> streamRecentlyPlayedRaw(
    String userId, {
    int limit = 20,
  }) {
    if (userId.isEmpty) return const Stream.empty();
    return _userCol(userId).orderBy('timestamp', descending: true).limit(limit).snapshots();
  }

  /// Optionally can remove old entries for a user
  static Future<void> clearForUser(String userId) async {
    final snap = await _userCol(userId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }
}
