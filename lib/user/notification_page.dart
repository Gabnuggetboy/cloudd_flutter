import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';

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
    final data = notifDoc.data();
    if (data == null) return;
    final expId = data['experienceId'] as String?;
    final userEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (expId == null || userEmail == null) return;

    final expRef = FirebaseFirestore.instance
        .collection('Experiences')
        .doc(expId);
    final expSnap = await expRef.get();
    final expData = expSnap.data();
    final collaborators =
        (expData?['collaborators'] as List?)
            ?.map((c) => Map<String, dynamic>.from(c as Map))
            .toList() ??
        [];

    bool updated = false;
    for (final c in collaborators) {
      final cEmail = (c['email'] as String?)?.toLowerCase();
      final cUid = c['uid'] as String?;
      if ((cEmail == userEmail || (userUid != null && cUid == userUid)) &&
          c['status'] == 'pending') {
        c['status'] = 'accepted';
        updated = true;
      }
    }

    if (updated) {
      await expRef.update({'collaborators': collaborators});
    }
    // to remove notif after accepting invite
    await notifDoc.reference.delete();
  }

  Future<void> _declineInvite(
    DocumentSnapshot<Map<String, dynamic>> notifDoc,
  ) async {
    final data = notifDoc.data();
    if (data == null) return;
    final expId = data['experienceId'] as String?;
    final userEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    final userUid = FirebaseAuth.instance.currentUser?.uid;
    if (expId == null || userEmail == null) return;

    final expRef = FirebaseFirestore.instance
        .collection('Experiences')
        .doc(expId);
    final expSnap = await expRef.get();
    final expData = expSnap.data();
    final collaborators =
        (expData?['collaborators'] as List?)
            ?.map((c) => Map<String, dynamic>.from(c as Map))
            .toList() ??
        [];

    collaborators.removeWhere((c) {
      final cEmail = (c['email'] as String?)?.toLowerCase();
      final cUid = c['uid'] as String?;
      return (cEmail == userEmail || (userUid != null && cUid == userUid)) &&
          c['status'] == 'pending';
    });

    await expRef.update({'collaborators': collaborators});
    // to remove notif after declining invite
    await notifDoc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    final hasUidStream = _notifByUid != null;
    final hasEmailStream = _notifByEmail != null;
    final primaryStream = _notifByUid ?? _notifByEmail;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TopSettingsTitleWidget(
                showCloudd: false,
                showSettings: true,
                showNotifications: true,
              ),
            ),
            Expanded(
              child: primaryStream == null
                  ? const Center(child: Text('Not logged in'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: primaryStream,
                      builder: (context, primarySnap) {
                        final primaryDocs = primarySnap.data?.docs ?? [];

                        // If only one stream is available, show it directly.
                        if (!hasUidStream || !hasEmailStream) {
                          final docs = [...primaryDocs]
                            ..sort((a, b) {
                              final ta = a.data()['createdAt'] as Timestamp?;
                              final tb = b.data()['createdAt'] as Timestamp?;
                              return (tb?.millisecondsSinceEpoch ?? 0)
                                  .compareTo(ta?.millisecondsSinceEpoch ?? 0);
                            });

                          if (primarySnap.connectionState ==
                                  ConnectionState.waiting &&
                              docs.isEmpty) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return _NotificationList(
                            docs: docs,
                            onAccept: _acceptInvite,
                            onDecline: _declineInvite,
                          );
                        }

                        // Both streams are available: merge uid + email.
                        return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>
                        >(
                          stream: _notifByEmail,
                          builder: (context, emailSnap) {
                            final emailDocs = emailSnap.data?.docs ?? [];
                            final merged =
                                <
                                  String,
                                  QueryDocumentSnapshot<Map<String, dynamic>>
                                >{};
                            for (final d in primaryDocs) {
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

                            final waiting =
                                (primarySnap.connectionState ==
                                    ConnectionState.waiting ||
                                emailSnap.connectionState ==
                                    ConnectionState.waiting);

                            if (waiting && docs.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            return _NotificationList(
                              docs: docs,
                              onAccept: _acceptInvite,
                              onDecline: _declineInvite,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        context: context,
        onIconTap: (index) {},
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>> doc)
  onAccept;
  final Future<void> Function(DocumentSnapshot<Map<String, dynamic>> doc)
  onDecline;

  const _NotificationList({
    required this.docs,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final d = docs[index];
        final data = d.data();
        final type = data['type'] ?? '';
        if (type == 'invite') {
          return InviteNotificationItem(
            doc: d,
            onAccept: () => onAccept(d),
            onDecline: () => onDecline(d),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(data['message'] ?? 'Notification'),
        );
      },
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
    final data = doc.data() ?? {};
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
