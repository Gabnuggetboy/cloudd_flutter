import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/user/explore_experience_page.dart';
import 'package:cloudd_flutter/user/category_experiences_page.dart';
import 'package:cloudd_flutter/services/recently_played_service.dart';
import 'package:cloudd_flutter/models/recently_played.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/models/user.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:math';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppUser? _currentUserProfile;

  List<Experience> _recommendedExperiences = [];
  bool _recommendedLoading = true;

  List<Experience> _popularExperiences = [];
  bool _popularLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
    _loadRecommendedExperiences();
    _loadMostPopularExperiences();
  }

  Future<String> getCategoryImageUrl(String category) async {
    final storage = FirebaseStorage.instance;

    switch (category.toLowerCase()) {
      case 'workshop':
        return await storage
            .ref('categories_images/workshop.jpg')
            .getDownloadURL();
      case 'art':
        return await storage.ref('categories_images/art.jpg').getDownloadURL();
      case 'technology':
        return await storage
            .ref('categories_images/technology.jpg')
            .getDownloadURL();
      case 'education':
        return await storage
            .ref('categories_images/education.jpg')
            .getDownloadURL();
      case 'entertainment':
        return await storage
            .ref('categories_images/entertainment.jpg')
            .getDownloadURL();
      default:
        return '';
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      setState(() {
        _currentUserProfile = AppUser.fromDoc(doc);
      });
    } catch (_) {}
  }

  Future<void> _loadRecommendedExperiences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _recommendedLoading = true);

    // Model not integrated yet
    final signupsSnap = await FirebaseFirestore.instance
        .collection('experience_signups')
        .where('userId', isEqualTo: user.uid)
        .get();

    if (signupsSnap.docs.isEmpty) {
      setState(() {
        _recommendedExperiences = [];
        _recommendedLoading = false;
      });
      return;
    }

    final experienceIds = signupsSnap.docs
        .map((d) => (d.data()['experienceId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (experienceIds.isEmpty) {
      setState(() {
        _recommendedExperiences = [];
        _recommendedLoading = false;
      });
      return;
    }

    final experiencesSnap = await FirebaseFirestore.instance
        .collection('Experiences')
        .where(FieldPath.documentId, whereIn: experienceIds)
        .get();

    
    final signedUpExperiences =
        experiencesSnap.docs.map((d) => Experience.fromDoc(d)).toList();

    final Map<String, int> categoryCount = {};
    for (final exp in signedUpExperiences) {
      final c = exp.category;
      if (c != null && c.trim().isNotEmpty) {
        categoryCount[c] = (categoryCount[c] ?? 0) + 1;
      }
    }

    if (categoryCount.isEmpty) {
      setState(() {
        _recommendedExperiences = [];
        _recommendedLoading = false;
      });
      return;
    }

    final topCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selectedCategories = topCategories.take(2).map((e) => e.key).toList();

    final recSnap = await FirebaseFirestore.instance
        .collection('Experiences')
        .where('category', whereIn: selectedCategories)
        .where('enabled', isEqualTo: true)
        .get();

    final filteredExperiences =
        recSnap.docs
            .map((doc) => Experience.fromDoc(doc))
            .where((exp) => !experienceIds.contains(exp.id))
            .toList()
          ..shuffle(Random());

    setState(() {
      _recommendedExperiences = filteredExperiences.take(6).toList();
      _recommendedLoading = false;
    });
  }

  Future<void> _loadMostPopularExperiences() async {
    setState(() => _popularLoading = true);

    // No model integrated yet
    final signupsSnap = await FirebaseFirestore.instance
        .collection('experience_signups')
        .get();

    if (signupsSnap.docs.isEmpty) {
      setState(() {
        _popularExperiences = [];
        _popularLoading = false;
      });
      return;
    }

    final Map<String, int> counts = {};
    for (final doc in signupsSnap.docs) {
      final expId = (doc.data()['experienceId'] ?? '').toString();
      if (expId.isEmpty) continue;
      counts[expId] = (counts[expId] ?? 0) + 1;
    }

    final sortedIds = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topIds = sortedIds.take(6).map((e) => e.key).toList();

    if (topIds.isEmpty) {
      setState(() {
        _popularExperiences = [];
        _popularLoading = false;
      });
      return;
    }

    final expSnap = await FirebaseFirestore.instance
        .collection('Experiences')
        .where(FieldPath.documentId, whereIn: topIds)
        .where('enabled', isEqualTo: true)
        .get();
    // Use Experience model
    final experiences = expSnap.docs
        .map((doc) => Experience.fromDoc(doc))
        .toList();

    setState(() {
      _popularExperiences = experiences;
      _popularLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fullName = (_currentUserProfile?.name.trim().isNotEmpty ?? false)
        ? _currentUserProfile!.name.trim()
        : "User";

    final firstName = fullName.split(RegExp(r'\s+')).first;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TopSettingsTitleWidget(showCloudd: true, showSettings: true),

                  const SizedBox(height: 10),

                  /// Greetings
                  Text(
                    "Hi $firstName,",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "Find The Best Experiences for You",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Categories",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "See all",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),
                  SizedBox(
                    height: 90,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Experiences')
                          .where('enabled', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        // Use Experience model
                        final experiences = snapshot.data!.docs
                            .map((doc) => Experience.fromDoc(doc))
                            .toList();

                        final categories = experiences
                            .map((exp) => exp.category)
                            .where((c) => c != null && c.trim().isNotEmpty)
                            .cast<String>()
                            .toSet()
                            .toList();

                        if (categories.isEmpty) {
                          return Center(
                            child: Text(
                              'No categories',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CategoryExperiencesPage(category: category),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: 75,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      FutureBuilder<String>(
                                        future: getCategoryImageUrl(category),
                                        builder: (context, snapshot) {
                                          return Container(
                                            width: 65,
                                            height: 65,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color.fromRGBO(143, 148, 251, 1),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: snapshot.hasData && snapshot.data!.isNotEmpty
                                                ? Image.network(
                                                    snapshot.data!,
                                                    fit: BoxFit.cover,
                                                  )
                                                : const Icon(
                                                    Icons.category,
                                                    color: Colors.white,
                                                  ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 75,
                                        child: Text(
                                          category,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// Recommended Header with Refresh
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Recommended for You",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: "Refresh recommendations",
                        onPressed:
                            _recommendedLoading ? null : _loadRecommendedExperiences,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 190,
                    child: _recommendedLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _recommendedExperiences.isEmpty
                        ? Center(
                            child: Text(
                              'No recommendations yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recommendedExperiences.length,
                            itemBuilder: (context, index) {
                              final experience = _recommendedExperiences[index];

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
                                  width:
                                      MediaQuery.of(context).size.width * 0.6,
                                  margin: const EdgeInsets.only(right: 15),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child: (experience.imageUrl !=
                                                      null &&
                                                  experience.imageUrl!
                                                      .isNotEmpty)
                                              ? Image.network(
                                                  experience.imageUrl!,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 40,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                          ),
                  ),

                  const SizedBox(height: 30),

                  /// Most Popular Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Most Popular",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: "Refresh popular experiences",
                        onPressed:
                            _popularLoading ? null : _loadMostPopularExperiences,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 190,
                    child: _popularLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _popularExperiences.isEmpty
                        ? Center(
                            child: Text(
                              'No popular experiences yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _popularExperiences.length,
                            itemBuilder: (context, index) {
                              final experience = _popularExperiences[index];

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
                                  width:
                                      MediaQuery.of(context).size.width * 0.6,
                                  margin: const EdgeInsets.only(right: 15),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child: (experience.imageUrl !=
                                                      null &&
                                                  experience.imageUrl!
                                                      .isNotEmpty)
                                              ? Image.network(
                                                  experience.imageUrl!,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 40,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                          ),
                  ),

                  const SizedBox(height: 30),

                  // Recently Played Header
                  Text(
                    "Recently Played",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Recently Played Row (from Firestore per user)
                  SizedBox(
                    height: 200,
                    child: StreamBuilder<List<RecentlyPlayed>>(
                      stream: RecentlyPlayedService.streamCurrentUserRecent(),
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final items = snap.data!;
                        if (items.isEmpty) {
                          return Center(
                            child: Text(
                              'No recently played content',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }

                        // Fetch device contents once so we can try to find logos
                        return FutureBuilder<Map<String, DeviceContentResult>>(
                          future: DeviceLoadingService.fetchAllDeviceContents(),
                          builder: (context, deviceSnap) {
                            final deviceMap = deviceSnap.data;

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, index) {
                                final rp = items[index];

                                String? logoUrl =
                                    (rp.logoUrl != null &&
                                        rp.logoUrl!.isNotEmpty)
                                    ? rp.logoUrl
                                    : null;

                                // Fallback: try to find a logo/url from the device contents
                                if (logoUrl == null && deviceMap != null) {
                                  final dev = deviceMap[rp.device];
                                  if (dev != null) {
                                    for (final c in dev.contents) {
                                      if (c is Map<String, dynamic>) {
                                        final name =
                                            (c['name'] ?? c['title'] ?? '')
                                                as String;
                                        if (name.isNotEmpty &&
                                            name.toLowerCase() ==
                                                rp.boothName.toLowerCase()) {
                                          logoUrl =
                                              (c['logo'] ??
                                                      c['thumbnail'] ??
                                                      c['image'])
                                                  as String?;
                                          break;
                                        }
                                      } else if (c is String) {
                                        if (c.toLowerCase() ==
                                            rp.boothName.toLowerCase()) {
                                          // no metadata available
                                          logoUrl = null;
                                          break;
                                        }
                                      }
                                    }
                                  }
                                }

                                final baseUrl = DeviceLoadingService.getBaseUrl(
                                  rp.device,
                                );
                                final displayUrl =
                                    (logoUrl != null && logoUrl.isNotEmpty)
                                    ? (logoUrl.startsWith('http')
                                          ? logoUrl
                                          : '$baseUrl$logoUrl')
                                    : null;

                                return Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.42,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        height: 100,
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                          child: displayUrl != null
                                              ? Image.network(
                                                  displayUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Container(
                                                        color: const Color(
                                                          0xFFEFEFEF,
                                                        ),
                                                        child: const Center(
                                                          child: Icon(
                                                            Icons.image,
                                                            size: 40,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ),
                                                  loadingBuilder:
                                                      (context, child, prog) {
                                                        if (prog == null) {
                                                          return child;
                                                        }
                                                        return const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        );
                                                      },
                                                )
                                              : Container(
                                                  color: const Color(
                                                    0xFFEFEFEF,
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.videogame_asset,
                                                      size: 44,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rp.boothName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              rp.device,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontSize: 10,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color
                                                        ?.withValues(
                                                          alpha: 0.6,
                                                        ),
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              rp.experienceName,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(fontSize: 10),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            // show playtime if it exists
                                            Builder(
                                              builder: (context) {
                                                final int secs =
                                                    rp.playtimeSeconds;
                                                if (secs <= 0) {
                                                  return const SizedBox();
                                                }
                                                final mins = rp.playtimeMinutes;
                                                final remainder = secs % 60;
                                                final playtimeText = mins > 0
                                                    ? '${mins}m ${remainder}s'
                                                    : '${remainder}s';
                                                return Text(
                                                  'Playtime: $playtimeText',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontSize: 12,
                                                        color: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.color
                                                            ?.withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
