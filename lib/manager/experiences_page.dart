import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloudd_flutter/manager/widgets/bottom_navigation_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'experience_details.dart';

class ExperiencesPage extends StatefulWidget {
  const ExperiencesPage({super.key});

  @override
  State<ExperiencesPage> createState() => _ExperiencesPageState();
}

class _ExperiencesPageState extends State<ExperiencesPage> {
  bool experienceEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TopSettingsTitleWidget(
              //   showCloudd: false,
              //   showManageExperiences: true,
              // ),
              // Replaced settings icon with notifications icon
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

              /*
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.star,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Experience #1',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last Updated 30+ Days ago',
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
                      value: experienceEnabled,
                      onChanged: (value) {
                        setState(() {
                          experienceEnabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              */
              Expanded(
                child: Builder(
                  builder: (context) {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null)
                      return const Center(child: Text('Not logged in'));

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

                                // merge unique by doc id
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

                                if ((managerSnap.connectionState ==
                                        ConnectionState.waiting) &&
                                    (collabSnap.connectionState ==
                                        ConnectionState.waiting) &&
                                    (emailSnap.connectionState ==
                                        ConnectionState.waiting)) {
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
                                    final dataMap =
                                        (doc.data() as Map<String, dynamic>?) ??
                                        {};

                                    final boothsCount =
                                        (dataMap['booths'] as List?)?.length ??
                                        0;
                                    final name =
                                        (dataMap['name'] as String?) ??
                                        'Untitled Experience';
                                    final enabled =
                                        (dataMap['enabled'] as bool?) ?? false;
                                    final lastUpdatedTimestamp =
                                        dataMap['last_updated'] as Timestamp?;
                                    final lastUpdatedString =
                                        lastUpdatedTimestamp != null
                                        ? lastUpdatedTimestamp
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
                                            Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                image: dataMap['imageUrl'] != null
                                                    ? DecorationImage(
                                                        image: NetworkImage(dataMap['imageUrl']),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                                color: dataMap['imageUrl'] == null ? Colors.grey[300] : null,
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "$boothsCount Booths",
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
                                              value: enabled,
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
