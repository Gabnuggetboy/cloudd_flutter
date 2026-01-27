import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloudd_flutter/manager/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:cloudd_flutter/models/user.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/services/image_caching_service.dart';
import 'package:cloudd_flutter/services/queue_service.dart';

class ManagerAccountPage extends StatelessWidget {
  const ManagerAccountPage({super.key});

  String _formatJoinedDate(Timestamp? ts) {
    if (ts == null) return "Joined -";
    final dt = ts.toDate();
    return "Joined ${DateFormat('d MMM yyyy').format(dt)}";
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
                        radius: 60,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        backgroundImage:
                            (appUser.profileImageUrl != null &&
                                appUser.profileImageUrl!.trim().isNotEmpty)
                            ? ImageCacheService().getCachedImageProvider(
                                appUser.profileImageUrl!,
                              )
                            : null,
                        child:
                            (appUser.profileImageUrl == null ||
                                appUser.profileImageUrl!.trim().isEmpty)
                            ? Icon(
                                Icons.person,
                                size: 70,
                                color: Theme.of(
                                  context,
                                ).iconTheme.color?.withOpacity(0.6),
                              )
                            : null,
                      ),

                      const SizedBox(width: 15),

                      //Manager info from Firestore
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appUser.name.isNotEmpty
                                ? appUser.name
                                : "Unnamed Manager",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),

                          Text(
                            "Manager",
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),

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
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Display Collection",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      _displayBox(context),
                      const SizedBox(width: 10),
                      _displayBox(context),
                      const SizedBox(width: 10),
                      _displayBox(context),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "See All",
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    "Experiences",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  // Experiences list
                  _buildExperiencesList(context, uid),
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

  Widget _displayBox(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildExperiencesList(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Experiences').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data?.docs ?? [];

        // Filter: experiences created by user OR where user is an accepted collaborator
        final relevantDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // Check if user is manager/owner
          if (data['managerId'] == uid) return true;
          if ((data['owner'] as Map<String, dynamic>?)?['uid'] == uid) {
            return true;
          }

          // Check if user is an accepted collaborator
          final collaborators = (data['collaborators'] as List?) ?? [];
          return collaborators.any((c) {
            final cUid = (c as Map<String, dynamic>)['uid'] as String?;
            final status = c['status'] as String?;
            return cUid == uid && status == 'accepted';
          });
        }).toList();

        // Sort by last_updated
        relevantDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final ta =
              (aData['last_updated'] ?? aData['lastUpdated']) as Timestamp?;
          final tb =
              (bData['last_updated'] ?? bData['lastUpdated']) as Timestamp?;
          return (tb?.millisecondsSinceEpoch ?? 0).compareTo(
            ta?.millisecondsSinceEpoch ?? 0,
          );
        });

        if (relevantDocs.isEmpty) {
          return const Text('No experiences yet');
        }

        return Column(
          children: relevantDocs.map((doc) {
            final experience = Experience.fromDoc(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            );
            final category = experience.category?.isNotEmpty == true
                ? experience.category!
                : '${experience.booths.length} Booths';
            final boothsCount = experience.booths.length;
            final name = experience.name.isEmpty
                ? 'Untitled Experience'
                : experience.name;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Row(
                children: [
                  // Image or placeholder
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image:
                          experience.imageUrl != null &&
                              experience.imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(experience.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color:
                          experience.imageUrl == null ||
                              experience.imageUrl!.isEmpty
                          ? Colors.grey[300]
                          : null,
                    ),
                    child:
                        experience.imageUrl == null ||
                            experience.imageUrl!.isEmpty
                        ? const Icon(Icons.image, color: Colors.grey, size: 32)
                        : null,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        Text(
                          "$boothsCount Booths",
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Red text button to force stop experience
                  SizedBox(
                    width: 100,
                    child: TextButton(
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirm Action'),
                            content: Text(
                              'This will remove all users from queues and stop all running content for "${experience.name}". Are you sure?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Force Stop'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && context.mounted) {
                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Stopping content and clearing queues...',
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Call force stop
                          final result = await QueueService.forceStopExperience(
                            experience.booths,
                          );

                          // Show result
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.success
                                      ? 'Successfully stopped all content and cleared queues'
                                      : 'Some operations failed: ${result.errorMessages.join(", ")}',
                                ),
                                backgroundColor: result.success
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Force Reset',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
