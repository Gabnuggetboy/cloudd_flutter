import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';
import 'package:cloudd_flutter/services/web_scraper_service.dart';
import 'package:cloudd_flutter/services/webview_scraper_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/user/explore_experience_page.dart';
import 'package:cloudd_flutter/user/category_experiences_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<GameData> _recommendedGames = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _showWebView = false;

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  void _loadGames() {
    setState(() {
      _isLoading = true;
      _showWebView = true;
    });
  }

  void _refreshGames() {
    setState(() {
      _isRefreshing = true;
      _showWebView = true;
    });
  }

  void _onGamesFetched(List<GameData> games) {
    setState(() {
      _recommendedGames = games;
      _isLoading = false;
      _isRefreshing = false;
      _showWebView = false;
    });
  }

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
                    child: const Row(
                      children: [
                        Icon(Icons.search, size: 22),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Search for Experience...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                                margin: const EdgeInsets.only(right: 12),
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
                                    const SizedBox(height: 6),
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
                  SizedBox(
                    height: 140,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _recommendedGames.isEmpty
                        ? const Center(
                            child: Text(
                              'No games available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recommendedGames.length,
                            itemBuilder: (context, index) {
                              final game = _recommendedGames[index];
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
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        game.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.image,
                                                  size: 50,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            },
                                      ),
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.play_arrow,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Play',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
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
                        "Explore",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "Discover experiences",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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
            if (_showWebView)
              HiddenWebViewScraper(onDataFetched: _onGamesFetched),
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
