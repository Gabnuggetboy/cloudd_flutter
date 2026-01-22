import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloudd_flutter/manager/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:cloudd_flutter/models/user.dart';
import 'package:cloudd_flutter/services/image_caching_service.dart';

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
                            ? ImageCacheService().getCachedImageProvider(appUser.profileImageUrl!)
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
}
