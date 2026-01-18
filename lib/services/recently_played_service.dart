import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/models/recently_played.dart';

class RecentlyPlayedService {
  // Recently played will be a subcollection under the "users" collection
  static const int maxRecentlyPlayedPerUser =
      10; //This is to set how many recently played booths are shown in home page

  static CollectionReference _userCol(String userId) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(userId)
      .collection('RecentlyPlayed');

  /// Get current user's recent items stream (shows last N items, default 10)
  static Stream<List<RecentlyPlayed>> streamCurrentUserRecent({
    int limit = maxRecentlyPlayedPerUser,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return Stream.value([]);

    return _userCol(uid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => RecentlyPlayed.fromDoc(d)).toList(),
        );
  }

  // Add a recently played entry for a user
  static Future<String?> addRecentlyPlayed({
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
      'playtime_seconds': 0,
      'playtime_minutes': 0,
      // Use only `timestamp` (server timestamp)
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      // Try to find an existing entry for this user + booth + experience
      var existing = await _userCol(userId)
          .where('boothName', isEqualTo: boothName)
          .where('experienceId', isEqualTo: experienceId)
          .limit(1)
          .get();

      // If experienceId is empty (e.g., from queue launch) and no exact match found
      // search by just boothName and device to find the original entry
      if (existing.docs.isEmpty && experienceId.isEmpty) {
        existing = await _userCol(userId)
            .where('boothName', isEqualTo: boothName)
            .where('device', isEqualTo: device)
            .limit(1)
            .get();
      }

      if (existing.docs.isNotEmpty) {
        // Update the existing document's timestamp and any changed fields
        // Keep existing playtime so it will be updated separately via updatePlaytimeByDocId
        final docRef = existing.docs.first.reference;
        await docRef.update({
          'timestamp': FieldValue.serverTimestamp(),
          'device': device,
          'experienceName': experienceName,
          'logoUrl': logoUrl ?? '',
          // Reset playtime wont be here so that it can be preserved
        });
        await _enforceLimitForUser(userId);
        return docRef.id;
      } else {
        // else when no existing entry then add a new one
        final docRef = await _userCol(userId).add(payload);
        await _enforceLimitForUser(userId);
        return docRef.id;
      }
    } catch (e) {
      final docRef = await _userCol(userId).add(payload);
      try {
        await _enforceLimitForUser(userId);
      } catch (_) {}
      return docRef.id;
    }
  }

  // Update playtime (seconds and minutes) for existing RecentlyPlayed doc
  // Adds any new seconds for booths playtime
  static Future<void> updatePlaytimeByDocId({
    required String userId,
    required String docId,
    required int seconds,
  }) async {
    if (userId.isEmpty || docId.isEmpty) return;

    // Fetch current playtime
    final docRef = _userCol(userId).doc(docId);
    final docSnap = await docRef.get();
    final data = docSnap.data() as Map<String, dynamic>?;

    // Get existing playtime or default to 0
    final currentSeconds = (data?['playtime_seconds'] as int?) ?? 0;
    final newTotalSeconds = currentSeconds + seconds;
    final newTotalMinutes = newTotalSeconds ~/ 60;

    await docRef.update({
      'playtime_seconds': newTotalSeconds,
      'playtime_minutes': newTotalMinutes,
    });
  }

  // To ensure a user doesn't have more than [maxRecentlyPlayedPerUser] documents.
  static Future<void> _enforceLimitForUser(String userId) async {
    if (userId.isEmpty) return;

    final snap = await _userCol(
      userId,
    ).orderBy('timestamp', descending: true).get();

    final docs = snap.docs;
    if (docs.length <= maxRecentlyPlayedPerUser) return;

    final batch = FirebaseFirestore.instance.batch();

    // Documents after index [maxRecentlyPlayedPerUser - 1] are the oldest
    for (var i = maxRecentlyPlayedPerUser; i < docs.length; i++) {
      batch.delete(docs[i].reference);
    }

    await batch.commit();
  }

  /// Optionally can remove all entries for a user
  static Future<void> clearForUser(String userId) async {
    final snap = await _userCol(userId).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) batch.delete(doc.reference);
    await batch.commit();
  }
}
