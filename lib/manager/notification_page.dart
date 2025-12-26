import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';

// Reusable helper to delete a notification document from anywhere.
Future<void> deleteNotificationDoc(
  DocumentReference<Map<String, dynamic>> ref,
) async {
  try {
    await ref.delete();
  } catch (e) {
    // ignore errors
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notifByUid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notifByEmail;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailLower = user.email?.toLowerCase();
      _notifByUid = FirebaseFirestore.instance
          .collection('Notifications')
          .where('recipientUid', isEqualTo: user.uid)
          .snapshots();
      if (emailLower != null) {
        _notifByEmail = FirebaseFirestore.instance
            .collection('Notifications')
            .where('recipientEmail', isEqualTo: emailLower)
            .snapshots();
      }
    }
  }

  Future<void> _acceptInvite(
    DocumentSnapshot<Map<String, dynamic>> notifDoc,
  ) async {
    final data = notifDoc.data()!;
    final expId = data['experienceId'];
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email?.toLowerCase();
    final userUid = user?.uid;
    if (expId == null || userEmail == null || userUid == null) return;

    final expRef = FirebaseFirestore.instance
        .collection('Experiences')
        .doc(expId);
    final expSnap = await expRef.get();
    final expData = expSnap.data();
    List coll = [];
    if (expData != null && expData['collaborators'] != null)
      coll = List.from(expData['collaborators']);

    // update collaborator status and ensure uid is present
    for (var c in coll) {
      final cEmail = (c['email'] as String?)?.toLowerCase();
      if (cEmail == userEmail && c['status'] == 'pending') {
        c['status'] = 'accepted';
        // ensure uid is stored for indexing
        c['uid'] = userUid;
      }
    }

    // Update collaborators and also ensure accepted collaborators are indexed
    final Set<String> collabUids = {};
    final Set<String> collabEmails = {};
    for (var c in coll) {
      final status = (c['status'] as String?) ?? '';
      if (status != 'accepted') continue;
      final cuid = (c['uid'] as String?);
      final cemail = (c['email'] as String?)?.toLowerCase();
      if (cuid != null && cuid.isNotEmpty) collabUids.add(cuid);
      if (cemail != null && cemail.isNotEmpty) collabEmails.add(cemail);
    }

    await expRef.update({
      'collaborators': coll,
      'collaboratorUids': collabUids.toList(),
      'collaboratorEmails': collabEmails.toList(),
    });

    // delete the notification doc after accepting
    await deleteNotificationDoc(notifDoc.reference);
    setState(() {});
  }

  Future<void> _declineInvite(
    DocumentSnapshot<Map<String, dynamic>> notifDoc,
  ) async {
    final data = notifDoc.data()!;
    final expId = data['experienceId'];
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email?.toLowerCase();
    if (expId == null || userEmail == null) return;

    final expRef = FirebaseFirestore.instance
        .collection('Experiences')
        .doc(expId);
    final expSnap = await expRef.get();
    final expData = expSnap.data();
    List coll = [];
    if (expData != null && expData['collaborators'] != null)
      coll = List.from(expData['collaborators']);

    coll.removeWhere(
      (c) =>
          (c['email'] as String?)?.toLowerCase() == userEmail &&
          c['status'] == 'pending',
    );

    // Also update collaborator index arrays to remove any accepted entries (shouldn't be any)
    final Set<String> collabUids = {};
    final Set<String> collabEmails = {};
    for (var c in coll) {
      final status = (c['status'] as String?) ?? '';
      if (status != 'accepted') continue;
      final cuid = (c['uid'] as String?);
      final cemail = (c['email'] as String?)?.toLowerCase();
      if (cuid != null && cuid.isNotEmpty) collabUids.add(cuid);
      if (cemail != null && cemail.isNotEmpty) collabEmails.add(cemail);
    }

    await expRef.update({
      'collaborators': coll,
      'collaboratorUids': collabUids.toList(),
      'collaboratorEmails': collabEmails.toList(),
    });

    // delete the notification doc after declining
    await deleteNotificationDoc(notifDoc.reference);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TopSettingsTitleWidget(
                showCloudd: false,
                showSettings: false,
                showNotifications: true,
                showNotificationIcon: false,
              ),
            ),
            Expanded(
              child: _notifByUid == null && _notifByEmail == null
                  ? const Center(child: Text('Not logged in'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _notifByUid ?? _notifByEmail!,
                      builder: (context, uidSnap) {
                        final uidDocs = uidSnap.data?.docs ?? [];
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _notifByEmail,
                          builder: (context, emailSnap) {
                            final emailDocs = emailSnap.data?.docs ?? [];
                            // merge unique by doc id
                            final Map<
                              String,
                              QueryDocumentSnapshot<Map<String, dynamic>>
                            >
                            merged = {};
                            for (final d in uidDocs) {
                              merged[d.id] = d;
                            }
                            for (final d in emailDocs) {
                              merged[d.id] = d;
                            }
                            final docs = merged.values.toList()
                              ..sort((a, b) {
                                final ta = a.data()['createdAt'] as Timestamp?;
                                final tb = b.data()['createdAt'] as Timestamp?;
                                return (tb?.millisecondsSinceEpoch ?? 0)
                                    .compareTo(ta?.millisecondsSinceEpoch ?? 0);
                              });

                            if (uidSnap.connectionState ==
                                    ConnectionState.waiting &&
                                (emailSnap.connectionState ==
                                    ConnectionState.waiting)) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (docs.isEmpty) {
                              return ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: const [
                                  SizedBox(height: 20),
                                  Center(
                                    child: Text(
                                      'No notifications.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final d = docs[index];
                                final data = d.data();
                                final type = data['type'] ?? '';
                                if (type == 'invite') {
                                  return InviteNotificationItem(
                                    doc: d,
                                    onAccept: () => _acceptInvite(d),
                                    onDecline: () => _declineInvite(d),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    data['message'] ?? 'Notification',
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class InviteNotificationItem extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const InviteNotificationItem({
    super.key,
    required this.doc,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data()!;
    final from = data['fromEmail'] ?? '';
    final expName = data['experienceName'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final timeText = createdAt != null
        ? createdAt.toDate().toString().split('.').first
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invitation to join $expName from $from',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap Accept to join this experience.',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                timeText,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: onDecline,
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                  IconButton(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
