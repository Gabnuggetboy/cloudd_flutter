import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExperienceService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference get _experiences =>
      _db.collection('experiences');

  String get _uid => _auth.currentUser!.uid;

  // For creating experience
  Future<String> createExperience({
    required String name,
    String? category,
    String? device,
    String? description,
    String? logoUrl,
  }) async {
    final doc = _experiences.doc();

    await doc.set({
      'name': name,
      'category': category,
      'device': device,
      'description': description,
      'logoUrl': logoUrl,
      'enabled': true,
      'creatorId': _uid,
      'managerId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'booths': [],
      'collaborators': [
        {
          'uid': _uid,
          'role': 'owner',
          'addedAt': FieldValue.serverTimestamp(),
        }
      ],
    });

    return doc.id;
  }

  // Fetch exeperiences for current user
  Stream<QuerySnapshot> getUserExperiences() {
    return _experiences.where(
      'collaborators',
      arrayContains: {'uid': _uid},
    ).snapshots();
  }

  // Get experience by ID
  Future<DocumentSnapshot> getExperience(String id) {
    return _experiences.doc(id).get();
  }

  // Enable experience
  Future<void> updateExperience(String id, Map<String, dynamic> data) {
    data['lastUpdated'] = FieldValue.serverTimestamp();
    return _experiences.doc(id).update(data);
  }

  // Enable/disable experience
  Future<void> setEnabled(String id, bool enabled) {
    return _experiences.doc(id).update({
      'enabled': enabled,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  //Delete experience
  Future<void> deleteExperience(String id) async {
    final doc = await _experiences.doc(id).get();
    final data = doc.data() as Map<String, dynamic>;

    if (data['creatorId'] != _uid) {
      throw Exception('Only owner can delete');
    }

    await _experiences.doc(id).delete();
  }
}
