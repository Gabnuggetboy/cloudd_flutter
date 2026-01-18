import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:cloudd_flutter/models/notification.dart';
import 'package:cloudd_flutter/services/experience_service.dart';

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
  final _service = ExperienceService();
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
    final notification = AppNotification.fromDoc(notifDoc);
    final expId = notification.experienceId;
    if (expId == null) return;

    try {
      await _service.acceptCollaboratorInvite(expId);
      await deleteNotificationDoc(notifDoc.reference);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation accepted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
    }
  }

  Future<void> _declineInvite(
    DocumentSnapshot<Map<String, dynamic>> notifDoc,
  ) async {
    final notification = AppNotification.fromDoc(notifDoc);
    final expId = notification.experienceId;
    if (expId == null) return;

    try {
      await _service.declineCollaboratorInvite(expId);
      await deleteNotificationDoc(notifDoc.reference);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
      }
    }
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
                                final notification = AppNotification.fromDoc(d);
                                if (notification.type == 'invite') {
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
                                    notification.message ?? 'Notification',
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
    final notification = AppNotification.fromDoc(doc);
    final from = notification.senderEmail ?? '';
    final expName = notification.experienceName ?? '';
    final createdAt = notification.createdAt;
    final timeText = createdAt.toDate().toString().split('.').first;

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
