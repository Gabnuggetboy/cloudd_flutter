import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class iCubeTestPage extends StatefulWidget {
  final bool selectionMode;
  final String? managerId;
  final String? experienceId;

  const iCubeTestPage({
    super.key,
    this.selectionMode = false,
    this.managerId,
    this.experienceId,
  });

  @override
  State<iCubeTestPage> createState() => _iCubeTestPageState();
}

class _iCubeTestPageState extends State<iCubeTestPage> {
  final String apiBaseUrl = 'http://192.168.0.143:5000';
  List<dynamic> contents = [];
  bool isLoading = true;
  String? errorMessage;
  String? runningContent;
  Set<String> selectedContents = {};
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  final Duration requestTimeout = const Duration(seconds: 10);

  final List<String> tagOrder = [
    'Demo',
    'Math',
    'Science',
    'Healthcare',
    'Therapeutic',
    'Entertainment',
    'Festivities',
    'Sports',
    'Music',
    'Art',
    'Language',
    'Food',
    'Simulation',
    'Local',
  ];

  Map<String, List<dynamic>> groupAndSortContents() {
    // Filter contents based on search query (name or tag)
    final query = searchQuery.trim().toLowerCase();
    final items = query.isEmpty
        ? contents
        : contents.where((content) {
            final name = (content['name'] ?? '').toString().toLowerCase();
            final tag = (content['tag'] ?? '').toString().toLowerCase();
            return name.contains(query) || tag.contains(query);
          }).toList();

    Map<String, List<dynamic>> grouped = {};

    for (var content in items) {
      final tag = content['tag'] ?? 'Other';
      if (!grouped.containsKey(tag)) {
        grouped[tag] = [];
      }
      grouped[tag]!.add(content);
    }

    final sortedGroups = <String, List<dynamic>>{};
    for (var tag in tagOrder) {
      if (grouped.containsKey(tag)) {
        sortedGroups[tag] = grouped[tag]!;
      }
    }

    for (var tag in grouped.keys) {
      if (!tagOrder.contains(tag)) {
        sortedGroups[tag] = grouped[tag]!;
      }
    }

    return sortedGroups;
  }

  @override
  void initState() {
    super.initState();
    if (!widget.selectionMode) {
      _loadRunningFromPrefs();
    }
    // Only load stored selections when selection mode AND we have a concrete
    // experienceId. For a new experience (experienceId == null) we must start
    // with an empty selection so different creations don't share a 'temp'
    // selection document.
    if (widget.selectionMode &&
        widget.managerId != null &&
        widget.experienceId != null) {
      _loadSelectedContents();
    }
    fetchContents();
  }

  Future<void> _loadSelectedContents() async {
    if (widget.managerId == null || widget.experienceId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection("ManagerContentSelections")
          .doc("${widget.managerId}_icube_${widget.experienceId}")
          .get();

      if (doc.exists && doc.data()?['selectedContents'] != null) {
        setState(() {
          selectedContents = Set<String>.from(doc.data()!['selectedContents']);
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveSelectedContents() async {
    // Don't persist selections for a temporary/new experience (no id).
    if (widget.managerId == null || widget.experienceId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection("ManagerContentSelections")
          .doc("${widget.managerId}_icube_${widget.experienceId}")
          .set({
            "managerId": widget.managerId,
            "device": "iCube",
            "experienceId": widget.experienceId,
            "selectedContents": selectedContents.toList(),
            "lastUpdated": Timestamp.now(),
          });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadRunningFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('running_content');
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          runningContent = saved;
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> clearRunningState() async {
    setState(() {
      runningContent = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('running_content');
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchContents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/contents'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final contentsList = json.decode(response.body) as List<dynamic>;

        // Fetch tags for each content
        for (var content in contentsList) {
          if (content['has_tag'] == true && content['tag_url'] != null) {
            try {
              final tagResponse = await http
                  .get(Uri.parse('$apiBaseUrl${content['tag_url']}'))
                  .timeout(requestTimeout);

              if (tagResponse.statusCode == 200) {
                // The response is plain text, not JSON
                final tagText = tagResponse.body.trim();
                content['tag'] = tagText.isNotEmpty ? tagText : 'Other';
              } else {
                content['tag'] = 'Other';
              }
            } catch (e) {
              content['tag'] = 'Other';
            }
          } else {
            content['tag'] = 'Other';
          }
        }

        setState(() {
          contents = contentsList;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load contents: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Please connect to Digital_Dream_2_5G wifi.';
        isLoading = false;
      });
    }
  }

  Future<void> launchContent(String contentName) async {
    try {
      if (runningContent != null && runningContent != contentName) {
        final stopping = await stopContent(runningContent!);
        if (!stopping) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to stop previous content'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final response = await http
          .get(Uri.parse('$apiBaseUrl/launch/$contentName'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          runningContent = contentName;
        });
        // persist running content
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('running_content', contentName);
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launching ${data['content']}: ${data['status']}'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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

  Future<bool> stopContent(String contentName) async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/close/$contentName'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            runningContent = null;
          });
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('running_content');
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stopped ${data['closed_exe']}'),
              duration: Duration(seconds: 2),
            ),
          );
          return true;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Build executable not found'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop content'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Add iCube Content' : 'iCube Test'),
        backgroundColor: const Color.fromRGBO(143, 148, 251, 1),
        foregroundColor: Colors.white,
        actions: widget.selectionMode
            ? [
                TextButton(
                  onPressed: () async {
                    await _saveSelectedContents();
                    Navigator.pop(context, selectedContents.toList());
                  },
                  child: Text(
                    'Done',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ]
            : null,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () {},
        child: Stack(
          children: [
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red, fontSize: 14),
                            textAlign: TextAlign.left,
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: fetchContents,
                            icon: Icon(Icons.refresh),
                            label: Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromRGBO(143, 148, 251, 1),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : contents.isEmpty
                ? const Center(child: Text('No contents available'))
                : Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: TextField(
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 12.0,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => searchQuery = value);
                          },
                        ),
                      ),
                      // Content list
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: fetchContents,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: _buildContentSections(),
                          ),
                        ),
                      ),
                    ],
                  ),
            if (!widget.selectionMode && runningContent != null)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 8,
                  color: Color.fromRGBO(143, 148, 251, 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_filled, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$runningContent is running',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => stopContent(runningContent!),
                          icon: Icon(Icons.stop, size: 18),
                          label: Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          onPressed: clearRunningState,
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Clear status',
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSections() {
    final groupedContents = groupAndSortContents();
    final sections = <Widget>[];

    for (var tag in groupedContents.keys) {
      // Add tag heading
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 12.0),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(102, 0, 191, 1),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );

      // content grid for tag
      sections.add(
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemCount: groupedContents[tag]!.length,
          itemBuilder: (context, index) {
            final content = groupedContents[tag]![index];
            final isSelected = widget.selectionMode
                ? selectedContents.contains(content['name'])
                : false;
            final isRunning = runningContent == content['name'];

            return _buildContentCard(content, isSelected, isRunning);
          },
        ),
      );

      // sized box for space in between tag header sections
      sections.add(SizedBox(height: 80.0));
    }

    return sections;
  }

  Widget _buildContentCard(dynamic content, bool isSelected, bool isRunning) {
    final contentName = content['name'];

    return GestureDetector(
      onTap: () {
        if (widget.selectionMode) {
          // In selection mode, toggle selection
          setState(() {
            if (selectedContents.contains(contentName)) {
              selectedContents.remove(contentName);
            } else {
              // Allow multiple selections: just add
              selectedContents.add(contentName);
            }
          });
        } else {
          // Original play/stop functionality
          setState(() {
            if (isSelected) {
              if (!isRunning) {
                launchContent(contentName);
              }
            }
          });
        }
      },
      child: Card(
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
                      '$apiBaseUrl${content['icon_url']}',
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
                    // Show selection overlay in selection mode
                    if (widget.selectionMode && isSelected)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    // Show play button if selected or running (non-selection mode)
                    if (!widget.selectionMode && (isSelected || isRunning))
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!isRunning)
                                GestureDetector(
                                  onTap: () => launchContent(contentName),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Color.fromRGBO(143, 148, 251, 1),
                                      size: 36,
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: [
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
                    contentName,
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
                        onPressed: () => stopContent(contentName),
                        icon: Icon(Icons.stop_circle, size: 18),
                        label: Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
