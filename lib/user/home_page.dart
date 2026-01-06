import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
// import 'package:cloudd_flutter/services/web_scraper_service.dart';
// import 'package:cloudd_flutter/services/webview_scraper_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/user/explore_experience_page.dart';
import 'package:cloudd_flutter/user/category_experiences_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // List<GameData> _recommendedGames = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  // bool _showWebView = false;

  List<QueryDocumentSnapshot> _recommendedExperiences = [];
  bool _recommendedLoading = true;

  List<QueryDocumentSnapshot> _popularExperiences = [];
  bool _popularLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGames();
    _loadRecommendedExperiences();
    _loadMostPopularExperiences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  void _loadGames() {
    setState(() {
      _isLoading = true;
      // _showWebView = true;
    });
  }

  void _refreshGames() {
    setState(() {
      _isRefreshing = true;
      // _showWebView = true;
    });
  }

  Future<void> _loadRecommendedExperiences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _recommendedLoading = true);

    //Get user signups
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

    //Get signed up experiences
    final experienceIds =
        signupsSnap.docs.map((d) => d['experienceId']).toSet().toList();

    final experiencesSnap = await FirebaseFirestore.instance
        .collection('Experiences')
        .where(FieldPath.documentId, whereIn: experienceIds)
        .get();

    //Count categories
    final Map<String, int> categoryCount = {};
    for (final doc in experiencesSnap.docs) {
      final category = doc['category'];
      if (category != null) {
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }
    }
    
    if (categoryCount.isEmpty) {
      setState(() {
        _recommendedExperiences = [];
        _recommendedLoading = false;
      });
      return;
    }

    //Top 2 categories
    final topCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selectedCategories =
        topCategories.take(2).map((e) => e.key).toList();

    //Fetch experiences from those categories
    final recSnap = await FirebaseFirestore.instance
        .collection('Experiences')
        .where('category', whereIn: selectedCategories)
        .where('enabled', isEqualTo: true)
        .get();
    

    final shuffled = recSnap.docs
      .where((doc) => !experienceIds.contains(doc.id))
      .toList()
    ..shuffle(Random());


    setState(() {
      _recommendedExperiences = shuffled.take(6).toList();
      _recommendedLoading = false;
    });
  }
  Future<void> _loadMostPopularExperiences() async {
    setState(() => _popularLoading = true);

    // 1. Get all signups
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

    // 2. Count signups per experience
    final Map<String, int> counts = {};
    for (final doc in signupsSnap.docs) {
      final expId = doc['experienceId'];
      counts[expId] = (counts[expId] ?? 0) + 1;
    }

    // 3. Sort by popularity
    final sortedIds = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topIds = sortedIds.take(6).map((e) => e.key).toList();

    // 4. Fetch experience documents
    final expSnap = await FirebaseFirestore.instance
        .collection('Experiences')
        .where(FieldPath.documentId, whereIn: topIds)
        .where('enabled', isEqualTo: true)
        .get();

    setState(() {
      _popularExperiences = expSnap.docs;
      _popularLoading = false;
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 1.3,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.trim();
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: "Search for Experience...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// Search Results
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 200,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('Experiences')
                            .where('enabled', isEqualTo: true)
                            .where('name', isGreaterThanOrEqualTo: _searchQuery)
                            .where('name', isLessThan: _searchQuery + '\uf8ff')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final docs = snapshot.data!.docs;

                          if (docs.isEmpty) {
                            return const Center(child: Text('No matching experiences'));
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final data = doc.data() as Map<String, dynamic>;

                              final name = data['name'] ?? 'Untitled';
                              final booths = (data['booths'] as List?) ?? [];

                              return ListTile(
                                title: Text(name),
                                subtitle: Text(
                                  '${booths.length} booth${booths.length == 1 ? '' : 's'}',
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExploreExperiencePage(
                                        experienceId: doc.id,
                                        experienceName: name,
                                      ),
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


                  const SizedBox(height: 25),

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
                          return const Center(child: CircularProgressIndicator());
                        }

                        // Extract unique categories
                        final categories = snapshot.data!.docs
                            .map((doc) => (doc.data() as Map<String, dynamic>)['category'])
                            .where((c) => c != null && c.toString().isNotEmpty)
                            .map((c) => c.toString())
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
                                    builder: (_) =>
                                        CategoryExperiencesPage(category: category),
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
                                        color: const Color.fromRGBO(143, 148, 251, 1),
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

                  /// Recommended Header with Refresh
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recommended for You",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: "Refresh recommendations",
                        onPressed: _recommendedLoading
                            ? null
                            : () {
                                _loadRecommendedExperiences();
                              },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 190,
                    child: _recommendedLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _recommendedExperiences.isEmpty
                            ? const Center(child: Text('No recommendations yet'))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _recommendedExperiences.length,
                                itemBuilder: (context, index) {
                                  final doc = _recommendedExperiences[index];
                                  final data = doc.data() as Map<String, dynamic>;

                                  final name = data['name'] ?? 'Untitled';
                                  final booths = (data['booths'] as List?) ?? [];
                                  final imageUrl = data['imageUrl'];

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExploreExperiencePage(
                                            experienceId: doc.id,
                                            experienceName: name,
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
                                              child: imageUrl != null
                                                  ? Image.network(
                                                      imageUrl,
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
                                                  name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${booths.length} booth${booths.length == 1 ? '' : 's'}',
                                                  style: const TextStyle(fontSize: 12),
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
                  // const Text(
                  //   "Most Popular",
                  //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  // ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Most Popular",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: "Refresh popular experiences",
                        onPressed: _recommendedLoading
                            ? null
                            : () {
                                _loadMostPopularExperiences();
                              },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    height: 190,
                    child: _popularLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _popularExperiences.isEmpty
                            ? const Center(child: Text('No popular experiences yet'))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _popularExperiences.length,
                                itemBuilder: (context, index) {
                                  final doc = _popularExperiences[index];
                                  final data = doc.data() as Map<String, dynamic>;

                                  final name = data['name'] ?? 'Untitled';
                                  final booths = (data['booths'] as List?) ?? [];
                                  final imageUrl = data['imageUrl'];

                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ExploreExperiencePage(
                                            experienceId: doc.id,
                                            experienceName: name,
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
                                              child: imageUrl != null
                                                  ? Image.network(
                                                      imageUrl,
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
                                                  name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${booths.length} booth${booths.length == 1 ? '' : 's'}',
                                                  style: const TextStyle(fontSize: 12),
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

                  /// Recently Played Header
                  const Text(
                    "Recently Played",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 15),

                  /// Recently Played Row
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Container(
                          width: MediaQuery.of(context).size.width * 0.42,
                          margin: EdgeInsets.only(
                            right: 15,
                            left: index == 0 ? 0 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8CFCF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/images/recently_played_${index + 1}.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
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

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('No experiences yet'),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: docs.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data =
                                (doc.data() as Map<String, dynamic>?) ?? {};
                            final name =
                                (data['name'] as String?) ?? 'Untitled';
                            final booths = (data['booths'] as List?) ?? [];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ExploreExperiencePage(
                                      experienceId: doc.id,
                                      experienceName: name,
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
                                          name,
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
                                      '${booths.length} booth${booths.length == 1 ? '' : 's'}',
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
            // Hidden WebView for scraping
            // if (_showWebView)
              // HiddenWebViewScraper(onDataFetched: _onGamesFetched),
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