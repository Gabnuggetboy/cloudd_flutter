import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloudd_flutter/manager/widgets/bottom_navigation_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'experience_details.dart';
import 'package:cloudd_flutter/models/experience.dart';

class ExperiencesPage extends StatefulWidget {
  const ExperiencesPage({super.key});

  @override
  State<ExperiencesPage> createState() => _ExperiencesPageState();
}

class _ExperiencesPageState extends State<ExperiencesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopSettingsTitleWidget(
                showCloudd: false,
                showManageExperiences: true,
                showSettings: false,
                showNotificationIcon: true,
              ),
              const SizedBox(height: 12),

              const Text(
                'Edit Your Experiences',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Builder(
                  builder: (context) {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      return const Center(child: Text('Not logged in'));
                    }

                    final managerStream = FirebaseFirestore.instance
                        .collection('Experiences')
                        .where('managerId', isEqualTo: user.uid)
                        .snapshots();

                    final collabByUid = FirebaseFirestore.instance
                        .collection('Experiences')
                        .where('collaboratorUids', arrayContains: user.uid)
                        .snapshots();

                    Stream<QuerySnapshot<Map<String, dynamic>>>? collabByEmail;
                    final emailLower = user.email?.toLowerCase();
                    if (emailLower != null) {
                      collabByEmail = FirebaseFirestore.instance
                          .collection('Experiences')
                          .where(
                            'collaboratorEmails',
                            arrayContains: emailLower,
                          )
                          .snapshots();
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: managerStream,
                      builder: (context, managerSnap) {
                        final managerDocs = managerSnap.data?.docs ?? [];

                        return StreamBuilder<QuerySnapshot>(
                          stream: collabByUid,
                          builder: (context, collabSnap) {
                            final collabDocs = collabSnap.data?.docs ?? [];

                            return StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>
                            >(
                              stream: collabByEmail,
                              builder: (context, emailSnap) {
                                final emailDocs = emailSnap.data?.docs ?? [];

                                // Merge unique documents by ID
                                final Map<String, QueryDocumentSnapshot>
                                merged = {};
                                for (final d in managerDocs) merged[d.id] = d;
                                for (final d in collabDocs) merged[d.id] = d;
                                for (final d in emailDocs) merged[d.id] = d;

                                final docs = merged.values.toList()
                                  ..sort((a, b) {
                                    final ta =
                                        (a.data()
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['last_updated']
                                            as Timestamp?;
                                    final tb =
                                        (b.data()
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['last_updated']
                                            as Timestamp?;
                                    return (tb?.millisecondsSinceEpoch ?? 0)
                                        .compareTo(
                                          ta?.millisecondsSinceEpoch ?? 0,
                                        );
                                  });

                                final isLoading =
                                    (managerSnap.connectionState ==
                                        ConnectionState.waiting) &&
                                    (collabSnap.connectionState ==
                                        ConnectionState.waiting) &&
                                    (emailSnap.connectionState ==
                                        ConnectionState.waiting);

                                if (isLoading) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (docs.isEmpty) {
                                  return const Center(
                                    child: Text('No experiences added yet'),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    final doc = docs[index];
                                    final experienceId = doc.id;
                                    final experience = Experience.fromDoc(doc);

                                    final category =
                                        experience.category?.isNotEmpty == true
                                        ? experience.category!
                                        : '${experience.booths.length} Booths';

                                    final name = experience.name.isEmpty
                                        ? 'Untitled Experience'
                                        : experience.name;

                                    final lastUpdatedString =
                                        experience.lastUpdated != null
                                        ? experience.lastUpdated!
                                              .toDate()
                                              .toString()
                                              .substring(0, 10)
                                        : 'Unknown';

                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ExperienceDetailsPage(
                                                  experienceId: experienceId,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                        ),
                                        child: Row(
                                          children: [
                                            // Logo or placeholder
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                width: 72,
                                                height: 72,
                                                color: Colors.grey[300],
                                                child:
                                                    experience.logoUrl !=
                                                            null &&
                                                        experience
                                                            .logoUrl!
                                                            .isNotEmpty
                                                    ? Image.network(
                                                        experience.logoUrl!,
                                                        fit: BoxFit.cover,
                                                        loadingBuilder:
                                                            (
                                                              context,
                                                              child,
                                                              loadingProgress,
                                                            ) {
                                                              if (loadingProgress ==
                                                                  null)
                                                                return child;
                                                              return Center(
                                                                child: CircularProgressIndicator(
                                                                  value:
                                                                      loadingProgress
                                                                              .expectedTotalBytes !=
                                                                          null
                                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                                            loadingProgress.expectedTotalBytes!
                                                                      : null,
                                                                ),
                                                              );
                                                            },
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) {
                                                              return const Icon(
                                                                Icons
                                                                    .image_not_supported,
                                                                color:
                                                                    Colors.grey,
                                                              );
                                                            },
                                                      )
                                                    : const Icon(
                                                        Icons.image,
                                                        color: Colors.grey,
                                                        size: 32,
                                                      ),
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    category,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Last Updated: $lastUpdatedString",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            Switch(
                                              value: experience.enabled,
                                              onChanged: (value) {
                                                FirebaseFirestore.instance
                                                    .collection("Experiences")
                                                    .doc(experienceId)
                                                    .update({
                                                      "enabled": value,
                                                      "last_updated":
                                                          Timestamp.now(),
                                                    });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ADD NEW EXPERIENCE BUTTON
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ExperienceDetailsPage(experienceId: null),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '+ Add New Experience',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        context: context,
        onIconTap: (index) {},
      ),
    );
  }
}
