import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cloudd_flutter/manager/add_icubecontent_page.dart';
import 'package:cloudd_flutter/manager/add_irigcontent_page.dart';
import 'package:cloudd_flutter/webapp_access_page.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/services/recently_played_service.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExploreExperiencePage extends StatefulWidget {
  final String experienceId;
  final String experienceName;

  const ExploreExperiencePage({
    super.key,
    required this.experienceId,
    required this.experienceName,
  });

  @override
  State<ExploreExperiencePage> createState() => _ExploreExperiencePageState();
}

class _ExploreExperiencePageState extends State<ExploreExperiencePage> {
  List<dynamic> icubeContents = [];
  List<dynamic> irigContents = [];
  List<dynamic> icreateContents = [];
  List<dynamic> storytimeContents = [];
  bool icubeLoading = true;
  bool irigLoading = true;
  bool icreateLoading = true;
  bool storytimeLoading = true;
  String? icubeError;
  String? irigError;
  String? icreateError;
  String? storytimeError;
  List<Map<String, dynamic>> booths = [];
  bool boothsLoading = true;
  String? boothsError;

  Map<String, String?> runningContent = {};
  // track when content was started (for duration calculation)
  final Map<String, DateTime?> runningStart = {};
  // map device -> recentlyPlayed doc id so we can update playtime on stop
  final Map<String, String?> runningRecentDocId = {};

  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchExperienceBooths();
    fetchICubeContents();
    fetchIRigContents();
    fetchICreateContents();
    fetchStorytimeContents();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchICubeContents() async {
    setState(() {
      icubeLoading = true;
      icubeError = null;
    });

    final result = await DeviceLoadingService.fetchICubeContents();

    setState(() {
      icubeContents = result.contents;
      icubeLoading = result.isLoading;
      icubeError = result.error;
    });
  }

  Future<void> fetchIRigContents() async {
    setState(() {
      irigLoading = true;
      irigError = null;
    });

    final result = await DeviceLoadingService.fetchIRigContents();

    setState(() {
      irigContents = result.contents;
      irigLoading = result.isLoading;
      irigError = result.error;
    });
  }

  Future<void> fetchICreateContents() async {
    setState(() {
      icreateLoading = true;
      icreateError = null;
    });

    final result = await DeviceLoadingService.fetchICreateContents();

    setState(() {
      icreateContents = result.contents;
      icreateLoading = result.isLoading;
      icreateError = result.error;
    });
  }

  Future<void> fetchStorytimeContents() async {
    setState(() {
      storytimeLoading = true;
      storytimeError = null;
    });

    final result = await DeviceLoadingService.fetchStorytimeContents();

    setState(() {
      storytimeContents = result.contents;
      storytimeLoading = result.isLoading;
      storytimeError = result.error;
    });
  }

  Future<void> fetchExperienceBooths() async {
    setState(() {
      boothsLoading = true;
      boothsError = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .get();
      if (!doc.exists) {
        setState(() {
          booths = [];
          boothsLoading = false;
          boothsError = 'Experience not found';
        });
        return;
      }

      final experience = Experience.fromDoc(doc);

      setState(() {
        booths = experience.booths;
        boothsLoading = false;
      });
    } catch (e) {
      setState(() {
        boothsError = 'Failed to load booths: $e';
        boothsLoading = false;
      });
    }
  }

  Future<void> launchContent(
    String device,
    String contentName, {
    String? boothName,
    String? logoUrl,
    String? experienceId,
    String? experienceName,
  }) async {
    // If content is already running on the same device, stop it first
    final currentRunningContent = runningContent[device];
    if (currentRunningContent != null && currentRunningContent.isNotEmpty) {
      await stopContent(device, currentRunningContent);
    }

    final result = await DeviceLoadingService.launchContent(
      device,
      contentName,
    );

    if (result.success) {
      setState(() {
        runningContent[device] = contentName;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));

      // Record recently played for the signed-in user
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          final docId = await RecentlyPlayedService.addRecentlyPlayed(
            userId: uid,
            device: device,
            boothName: boothName ?? contentName,
            experienceId: experienceId ?? widget.experienceId,
            experienceName: experienceName ?? widget.experienceName,
            logoUrl: logoUrl,
          );
          // store start time and doc id to update playtime when stopped
          runningStart[device] = DateTime.now();
          runningRecentDocId[device] = docId;
        }
      } catch (e) {
        // ignore: avoid_print
        print('Failed to write RecentlyPlayed: $e');
      }

      // Navigate to Storytime web app after launching Storytime content
      if (device == 'Storytime') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StoryTimeWebappPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> stopContent(String device, String contentName) async {
    final result = await DeviceLoadingService.stopContent(device, contentName);

    if (result.success) {
      // compute play duration and persist it if we have a start time and doc id
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final start = runningStart[device];
        final docId = runningRecentDocId[device];
        if (uid != null && uid.isNotEmpty && start != null && docId != null) {
          final seconds = DateTime.now().difference(start).inSeconds;
          await RecentlyPlayedService.updatePlaytimeByDocId(
            userId: uid,
            docId: docId,
            seconds: seconds,
          );
        }
      } catch (e) {
        // ignore: avoid_print
        print('Failed updating playtime: $e');
      }

      setState(() {
        runningContent[device] = null;
        runningStart.remove(device);
        runningRecentDocId.remove(device);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  List<dynamic> _filter(List<dynamic> items) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((content) {
      final name = (content['name'] ?? '').toString().toLowerCase();
      final tag = (content['tag'] ?? '').toString().toLowerCase();
      return name.contains(q) || tag.contains(q);
    }).toList();
  }

  Widget _buildBoothCard(Map<String, dynamic> booth) {
    final deviceRaw = (booth['device'] ?? '').toString();
    final device = deviceRaw.toLowerCase().contains('icube')
        ? 'iCube'
        : deviceRaw.toLowerCase().contains('irig')
        ? 'iRig'
        : deviceRaw.toLowerCase().contains('storytime')
        ? 'Storytime'
        : deviceRaw;
    final contentName = (booth['contentName'] as String?);

    // Find metadata from fetched lists
    final sourceList = device == 'iCube'
        ? icubeContents
        : device == 'iRig'
        ? irigContents
        : device == 'iCreate'
        ? icreateContents
        : device == 'Storytime'
        ? storytimeContents
        : [];
    final baseUrl = DeviceLoadingService.getBaseUrl(device);

    dynamic matched;
    if (contentName != null) {
      try {
        matched = sourceList.firstWhere(
          (c) => (c['name'] ?? '') == contentName,
          orElse: () => null,
        );
      } catch (_) {
        matched = null;
      }
    }

    final title = contentName ?? device;

    // If matched metadata exists, reuse the same card UI as in _buildSection
    if (matched != null) {
      final content = matched;
      final contentNameFound = content['name'];
      final isRunning = runningContent[device] == contentNameFound;

      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    Image.network(
                      '$baseUrl${content['icon_url']}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 64,
                            color: Colors.grey,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                    if (isRunning)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Running',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isRunning)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () => stopContent(device, contentNameFound),
                        icon: const Icon(Icons.stop_circle, size: 18),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () => launchContent(
                          device,
                          contentNameFound,
                          boothName: contentNameFound,
                          logoUrl: content['icon_url'] != null
                              ? '$baseUrl${content['icon_url']}'
                              : null,
                          experienceId: widget.experienceId,
                          experienceName: widget.experienceName,
                        ),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Play'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(
                            143,
                            148,
                            251,
                            1,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No matched metadata: show simple booth card
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Icon(Icons.vrpano)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contentName ?? 'No specific content',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (device == 'iCube' || device == 'iRig')
              ElevatedButton(
                onPressed: () {
                  // open device page for full content selection
                  // fallback: attempt to launch by name if provided
                  if (contentName != null) {
                    launchContent(
                      device,
                      contentName,
                      boothName: contentName,
                      experienceId: widget.experienceId,
                      experienceName: widget.experienceName,
                    );
                  } else {
                    // navigate to device full page
                    if (device == 'iCube') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              iCubeTestPage(selectionMode: false),
                        ),
                      );
                    } else if (device == 'iRig') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              IrigTestPage(selectionMode: false),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Open'),
              )
            else
              TextButton(onPressed: null, child: const Text('Info')),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String device,
    List<dynamic> list,
    bool loading,
    String? error,
    String baseUrl,
  ) {
    final filtered = _filter(list);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(error));
    if (filtered.isEmpty) {
      return const Center(child: Text('No contents available'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final content = filtered[index];
        final contentName = content['name'];
        final isRunning = runningContent[device] == contentName;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Image.network(
                        '$baseUrl${content['icon_url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: Colors.grey,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                      if (isRunning)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Running',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      contentName ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isRunning)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () => stopContent(device, contentName),
                          icon: const Icon(Icons.stop_circle, size: 18),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () => launchContent(
                            device,
                            contentName,
                            boothName: contentName,
                            logoUrl: content['icon_url'] != null
                                ? '$baseUrl${content['icon_url']}'
                                : null,
                            experienceId: widget.experienceId,
                            experienceName: widget.experienceName,
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Play'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromRGBO(
                              143,
                              148,
                              251,
                              1,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final hasRunningContent = runningContent.values.any(
          (content) => content != null && content.isNotEmpty,
        );

        if (hasRunningContent) {
          final shouldStop = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Content Running'),
                content: const Text(
                  'Please stop all content before exiting experience',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text(
                      'Stop all content',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          );

          if (shouldStop == true) {
            // Stop all running contents, then allow pop
            final running = runningContent.entries
                .where((e) => e.value != null && e.value!.isNotEmpty)
                .toList();
            for (var entry in running) {
              await stopContent(entry.key, entry.value!);
            }
            return true;
          }

          return false; // prevent exit if cancelled
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Explore: ${widget.experienceName}')),
        body: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              fetchExperienceBooths(),
              fetchICubeContents(),
              fetchIRigContents(),
              fetchICreateContents(),
              fetchStorytimeContents(),
            ]);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search contents',
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() => searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 16),

                // iCube booths (only booths listed in the experience)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'iCube',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (boothsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (boothsError != null)
                  Center(child: Text(boothsError!))
                else
                  Builder(
                    builder: (context) {
                      final icubeBooths = booths
                          .where(
                            (b) => (b['device'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains('icube'),
                          )
                          .toList();

                      // Apply search filter
                      final filteredBooths = searchQuery.trim().isEmpty
                          ? icubeBooths
                          : icubeBooths.where((b) {
                              final contentName = (b['contentName'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final query = searchQuery.trim().toLowerCase();
                              return contentName.contains(query);
                            }).toList();

                      if (filteredBooths.isEmpty) {
                        return const Center(child: Text('No iCube booths'));
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                        itemCount: filteredBooths.length,
                        itemBuilder: (context, index) => _buildBoothCard(
                          Map<String, dynamic>.from(
                            filteredBooths[index] as Map,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // iCreate booths
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'iCreate',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (boothsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (boothsError != null)
                  Center(child: Text(boothsError!))
                else
                  Builder(
                    builder: (context) {
                      final icreateBooths = booths
                          .where(
                            (b) => (b['device'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains('icreate'),
                          )
                          .toList();

                      // Apply search filter
                      final filteredBooths = searchQuery.trim().isEmpty
                          ? icreateBooths
                          : icreateBooths.where((b) {
                              final contentName = (b['contentName'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final query = searchQuery.trim().toLowerCase();
                              return contentName.contains(query);
                            }).toList();

                      if (filteredBooths.isEmpty) {
                        return const Center(child: Text('No iCreate booths'));
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                        itemCount: filteredBooths.length,
                        itemBuilder: (context, index) => _buildBoothCard(
                          Map<String, dynamic>.from(
                            filteredBooths[index] as Map,
                          ),
                        ),
                      );
                    },
                  ),

                // iRig booths
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'iRig',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (boothsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (boothsError != null)
                  Center(child: Text(boothsError!))
                else
                  Builder(
                    builder: (context) {
                      final irigBooths = booths
                          .where(
                            (b) => (b['device'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains('irig'),
                          )
                          .toList();

                      // Apply search filter
                      final filteredBooths = searchQuery.trim().isEmpty
                          ? irigBooths
                          : irigBooths.where((b) {
                              final contentName = (b['contentName'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final query = searchQuery.trim().toLowerCase();
                              return contentName.contains(query);
                            }).toList();

                      if (filteredBooths.isEmpty) {
                        return const Center(child: Text('No iRig booths'));
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                        itemCount: filteredBooths.length,
                        itemBuilder: (context, index) => _buildBoothCard(
                          Map<String, dynamic>.from(
                            filteredBooths[index] as Map,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // Storytime booths
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Storytime',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (boothsLoading)
                  const Center(child: CircularProgressIndicator())
                else if (boothsError != null)
                  Center(child: Text(boothsError!))
                else
                  Builder(
                    builder: (context) {
                      final storytimeBooths = booths
                          .where(
                            (b) => (b['device'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains('storytime'),
                          )
                          .toList();

                      // Apply search filter
                      final filteredBooths = searchQuery.trim().isEmpty
                          ? storytimeBooths
                          : storytimeBooths.where((b) {
                              final contentName = (b['contentName'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final query = searchQuery.trim().toLowerCase();
                              return contentName.contains(query);
                            }).toList();

                      if (filteredBooths.isEmpty) {
                        return const Center(child: Text('No Storytime booths'));
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                        itemCount: filteredBooths.length,
                        itemBuilder: (context, index) => _buildBoothCard(
                          Map<String, dynamic>.from(
                            filteredBooths[index] as Map,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
