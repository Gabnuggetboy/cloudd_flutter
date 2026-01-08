import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
// import 'package:cloudd_flutter/services/web_scraper_service.dart';
// import 'package:cloudd_flutter/services/webview_scraper_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/user/explore_experience_page.dart';
import 'package:cloudd_flutter/user/category_experiences_page.dart';
import 'package:cloudd_flutter/services/recently_played_service.dart';
import 'package:cloudd_flutter/models/recently_played.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // List<GameData> _recommendedGames = [];
  bool _isRefreshing = false;
  // bool _showWebView = false;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  void _loadGames() {
    setState(() {
      // _showWebView = true;
    });
  }

  void _refreshGames() {
    setState(() {
      _isRefreshing = true;
      // _showWebView = true;
    });
  }

  // void _onGamesFetched(List<GameData> games) {
  //   setState(() {
  //     _recommendedGames = games;
  //     _isLoading = false;
  //     _isRefreshing = false;
  //     _showWebView = false;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TopSettingsTitleWidget(showCloudd: true, showSettings: true),

                  const SizedBox(height: 10),

                  /// Greetings
                  const Text(
                    "Hi User,",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Text(
                    "Find The Best Experiences for You",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),

                  const SizedBox(height: 20),

                  /// Search Bar
                  // Container(
                  //   padding: const EdgeInsets.symmetric(horizontal: 15),
                  //   decoration: BoxDecoration(
                  //     border: Border.all(
                  //       color: Theme.of(context).dividerColor,
                  //       width: 1.3,
                  //     ),
                  //     borderRadius: BorderRadius.circular(10),
                  //   ),
                  //   child: const Row(
                  //     children: [
                  //       Icon(Icons.search, size: 22),
                  //       SizedBox(width: 10),
                  //       Expanded(
                  //         child: TextField(
                  //           decoration: InputDecoration(
                  //             hintText: "Search for Experience...",
                  //             border: InputBorder.none,
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),

                  // const SizedBox(height: 25),

                  /// Categories Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "Categories",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "See all",
                        style: TextStyle(
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
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        // Extract unique categories
                        final experiences = snapshot.data!.docs
                            .map((doc) => Experience.fromDoc(doc))
                            .toList();

                        final categories = experiences
                            .map((exp) => exp.category)
                            .where((c) => c != null && c.isNotEmpty)
                            .cast<String>()
                            .toSet()
                            .toList();

                        if (categories.isEmpty) {
                          return const Center(child: Text('No categories'));
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CategoryExperiencesPage(
                                      category: category,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 75,
                                margin: const EdgeInsets.only(right: 10),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 65,
                                      height: 65,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color.fromRGBO(
                                          143,
                                          148,
                                          251,
                                          1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.category,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
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

                  const SizedBox(height: 30),

                  /// Recommended Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recommended",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: _isRefreshing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        onPressed: _isRefreshing ? null : _refreshGames,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  /// Recommended Boxes
                  // SizedBox(
                  //   height: 140,
                  //   child: _isLoading
                  //       // ? const Center(child: CircularProgressIndicator())
                  //       // : _recommendedGames.isEmpty
                  //       ? const Center(
                  //           child: Text(
                  //             'No games available',
                  //             style: TextStyle(color: Colors.grey),
                  //           ),
                  //         )
                  //       : ListView.builder(
                  //           scrollDirection: Axis.horizontal,
                  //           // itemCount: _recommendedGames.length,
                  //           itemBuilder: (context, index) {
                  //             // final game = _recommendedGames[index];
                  //             return Container(
                  //               width: MediaQuery.of(context).size.width * 0.42,
                  //               margin: EdgeInsets.only(
                  //                 right: 15,
                  //                 left: index == 0 ? 0 : 0,
                  //               ),
                  //               decoration: BoxDecoration(
                  //                 color: const Color(0xFFD8CFCF),
                  //                 borderRadius: BorderRadius.circular(12),
                  //               ),
                  //               child: ClipRRect(
                  //                 borderRadius: BorderRadius.circular(12),
                  //                 child: Stack(
                  //                   fit: StackFit.expand,
                  //                   children: [
                  //                     Image.network(
                  //                       // game.imageUrl,
                  //                       // fit: BoxFit.cover,
                  //                       errorBuilder:
                  //                           (context, error, stackTrace) {
                  //                             return const Center(
                  //                               child: Icon(
                  //                                 Icons.image,
                  //                                 size: 50,
                  //                                 color: Colors.grey,
                  //                               ),
                  //                             );
                  //                           },
                  //                       loadingBuilder:
                  //                           (context, child, loadingProgress) {
                  //                             if (loadingProgress == null) {
                  //                               return child;
                  //                             }
                  //                             return const Center(
                  //                               child:
                  //                                   CircularProgressIndicator(),
                  //                             );
                  //                           },
                  //                     ),
                  //                     Center(
                  //                       child: Container(
                  //                         padding: const EdgeInsets.symmetric(
                  //                           horizontal: 16,
                  //                           vertical: 8,
                  //                         ),
                  //                         decoration: BoxDecoration(
                  //                           color: Colors.black.withValues(
                  //                             alpha: 0.6,
                  //                           ),
                  //                           borderRadius: BorderRadius.circular(
                  //                             20,
                  //                           ),
                  //                         ),
                  //                         child: const Row(
                  //                           mainAxisSize: MainAxisSize.min,
                  //                           children: [
                  //                             Icon(
                  //                               Icons.play_arrow,
                  //                               color: Colors.white,
                  //                               size: 20,
                  //                             ),
                  //                             SizedBox(width: 4),
                  //                             Text(
                  //                               'Play',
                  //                               style: TextStyle(
                  //                                 color: Colors.white,
                  //                                 fontWeight: FontWeight.w600,
                  //                               ),
                  //                             ),
                  //                           ],
                  //                         ),
                  //                       ),
                  //                     ),
                  //                   ],
                  //                 ),
                  //               ),
                  //             );
                  //           },
                  //         ),
                  // ),
                  const SizedBox(height: 30),

                  // Recently Played Header
                  const Text(
                    "Recently Played",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 10),

                  // Recently Played Row (from Firestore per user)
                  SizedBox(
                    height: 200,
                    child: StreamBuilder<List<RecentlyPlayed>>(
                      stream: RecentlyPlayedService.streamCurrentUserRecent(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(child: Text('Error: ${snap.error}'));
                        }
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final items = snap.data!;
                        if (items.isEmpty) {
                          return const Center(
                            child: Text('No recently played content'),
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
                                        color: Colors.black.withOpacity(0.05),
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
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              rp.device,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              rp.experienceName,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
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
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey,
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

                  const SizedBox(height: 40),
                  // Explore header (shows experiences across all managers)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "TESTING EXPERIENCES ONLY",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Explore list from Firestore (all experiences)
                  SizedBox(
                    height: 160,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('Experiences')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final experiences = snapshot.data!.docs
                            .map((doc) => Experience.fromDoc(doc))
                            .toList();

                        if (experiences.isEmpty) {
                          return const Center(
                            child: Text('No experiences yet'),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: experiences.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final experience = experiences[index];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExploreExperiencePage(
                                      experienceId: experience.id,
                                      experienceName: experience.name,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.6,
                                margin: EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          experience.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${experience.booths.length} booth${experience.booths.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color,
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
