import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:cloudd_flutter/models/user.dart';
import 'package:cloudd_flutter/user/explore_experience_page.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/services/image_caching_service.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  String _formatJoinedDate(Timestamp? ts) {
    if (ts == null) return "Joined -";
    final dt = ts.toDate();
    return "Joined ${DateFormat('d MMM yyyy').format(dt)}";
  }

  Stream<List<Experience>> streamSignedUpExperiences(String uid) async* {
    await for (final signupsSnap in FirebaseFirestore.instance
        .collection('experience_signups')
        .where('userId', isEqualTo: uid)
        .snapshots()) {
      final ids = signupsSnap.docs
          .map((d) => (d.data()['experienceId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (ids.isEmpty) {
        yield [];
        continue;
      }

      // Firestore whereIn limit = 10 -> chunk
      const chunkSize = 10;
      final List<Experience> results = [];

      for (int i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(i, (i + chunkSize).clamp(0, ids.length));

        final expSnap = await FirebaseFirestore.instance
            .collection('Experiences')
            .where(FieldPath.documentId, whereIn: chunk)
            .where('enabled', isEqualTo: true)
            .get();

        results.addAll(expSnap.docs.map((d) => Experience.fromDoc(d)));
      }

      // keep stable ordering
      results.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));

      yield results;
    }
  }


  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        body: SafeArea(child: Center(child: Text("Not logged in"))),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.data!.exists) {
              return const Center(child: Text("User profile not found"));
            }

            final appUser = AppUser.fromDoc(snapshot.data!);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TopSettingsTitleWidget(showCloudd: false, showSettings: true),
                  const SizedBox(height: 20),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //Profile image from profile_image_url
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        backgroundImage:
                            (appUser.profileImageUrl != null &&
                                appUser.profileImageUrl!.trim().isNotEmpty)
                            ? ImageCacheService().getCachedImageProvider(appUser.profileImageUrl!)
                            : null,
                        child:
                            (appUser.profileImageUrl == null ||
                                appUser.profileImageUrl!.trim().isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: Theme.of(
                                  context,
                                ).iconTheme.color?.withValues(alpha: 153),
                              )
                            : null,
                      ),

                      const SizedBox(width: 15),

                      //User info from Firestore
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appUser.name.isNotEmpty
                                ? appUser.name
                                : "Unnamed User",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),

                          const Text("", style: TextStyle(fontSize: 16)),

                          const SizedBox(height: 4),
                          Text(
                            _formatJoinedDate(appUser.createdAt),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit, size: 28),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Signed Up",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    height: 190,
                    child: StreamBuilder<List<Experience>>(
                      stream: streamSignedUpExperiences(uid),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snap.error}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }

                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final items = snap.data!;
                        if (items.isEmpty) {
                          return Text(
                            "No signups yet",
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final experience = items[index];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExploreExperiencePage(
                                      experienceId: experience.id,
                                      experienceName: experience.name,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.6,
                                margin: const EdgeInsets.only(right: 15),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        child: (experience.imageUrl != null &&
                                                experience.imageUrl!.isNotEmpty)
                                            ? ImageCacheService().getCachedImage(
                                                imageUrl: experience.imageUrl!,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child: Icon(Icons.image, size: 40),
                                                ),
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            experience.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${experience.booths.length} booth${experience.booths.length == 1 ? '' : 's'}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),


                  const SizedBox(height: 40),

                  const Text(
                    "Experiences",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        context: context,
        onIconTap: (index) {},
      ),
    );
  }

}
