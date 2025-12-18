import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cloudd_flutter/manager/add_icubecontent_page.dart';
import 'package:cloudd_flutter/manager/add_irigcontent_page.dart';

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
  final String icubeBase = 'http://192.168.0.143:5000';
  final String irigBase = 'http://192.168.0.126:5000';

  List<dynamic> icubeContents = [];
  List<dynamic> irigContents = [];
  bool icubeLoading = true;
  bool irigLoading = true;
  String? icubeError;
  String? irigError;
  List<Map<String, dynamic>> booths = [];
  bool boothsLoading = true;
  String? boothsError;

  String? runningDevice; // 'iCube' or 'iRig'
  String? runningContent;

  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchExperienceBooths();
    fetchICubeContents();
    fetchIRigContents();
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
    try {
      final res = await http
          .get(Uri.parse('$icubeBase/contents'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List<dynamic>;
        setState(() {
          icubeContents = list;
          icubeLoading = false;
        });
      } else {
        setState(() {
          icubeError = 'Failed to load iCube contents: ${res.statusCode}';
          icubeLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        icubeError = 'iCube: $e';
        icubeLoading = false;
      });
    }
  }

  Future<void> fetchIRigContents() async {
    setState(() {
      irigLoading = true;
      irigError = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$irigBase/contents'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List<dynamic>;
        setState(() {
          irigContents = list;
          irigLoading = false;
        });
      } else {
        setState(() {
          irigError = 'Failed to load iRig contents: ${res.statusCode}';
          irigLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        irigError = 'iRig: $e';
        irigLoading = false;
      });
    }
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
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      final raw = (data['booths'] as List?) ?? [];
      final parsed = <Map<String, dynamic>>[];
      for (var item in raw) {
        if (item is Map) {
          parsed.add(Map<String, dynamic>.from(item as Map));
        }
      }
      setState(() {
        booths = parsed;
        boothsLoading = false;
      });
    } catch (e) {
      setState(() {
        boothsError = 'Failed to load booths: $e';
        boothsLoading = false;
      });
    }
  }

  Future<void> launchContent(String device, String contentName) async {
    final base = device == 'iCube' ? icubeBase : irigBase;
    try {
      final res = await http
          .get(Uri.parse('$base/launch/$contentName'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          runningDevice = device;
          runningContent = contentName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launching ${data['content']}: ${data['status']}'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to launch content'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> stopContent(String device, String contentName) async {
    final base = device == 'iCube' ? icubeBase : irigBase;
    try {
      final res = await http
          .get(Uri.parse('$base/close/$contentName'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'success') {
          setState(() {
            runningDevice = null;
            runningContent = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Stopped ${data['closed_exe']}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (res.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Build executable not found'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to stop content'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        : deviceRaw;
    final contentName = (booth['contentName'] as String?);

    // Find metadata from fetched lists
    final sourceList = device == 'iCube'
        ? icubeContents
        : device == 'iRig'
        ? irigContents
        : [];
    final baseUrl = device == 'iCube'
        ? icubeBase
        : device == 'iRig'
        ? irigBase
        : '';

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
      final isRunning =
          runningDevice == device && runningContent == contentNameFound;

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
                        onPressed: () =>
                            launchContent(device, contentNameFound),
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
                    launchContent(device, contentName);
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
    if (filtered.isEmpty)
      return const Center(child: Text('No contents available'));

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
        final isRunning =
            runningDevice == device && runningContent == contentName;

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
                          onPressed: () => launchContent(device, contentName),
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
    return Scaffold(
      appBar: AppBar(title: Text('Explore: ${widget.experienceName}')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            fetchExperienceBooths(),
            fetchICubeContents(),
            fetchIRigContents(),
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
                    if (icubeBooths.isEmpty)
                      return const Center(child: Text('No iCube booths'));
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
                      itemCount: icubeBooths.length,
                      itemBuilder: (context, index) => _buildBoothCard(
                        Map<String, dynamic>.from(icubeBooths[index] as Map),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

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
                    if (irigBooths.isEmpty)
                      return const Center(child: Text('No iRig booths'));
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
                      itemCount: irigBooths.length,
                      itemBuilder: (context, index) => _buildBoothCard(
                        Map<String, dynamic>.from(irigBooths[index] as Map),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
