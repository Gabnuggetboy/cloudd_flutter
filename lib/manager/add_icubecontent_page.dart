import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/models/manager_content_selection.dart';

//THIS PAGE IS NOT IN USE, REPLACED BY add_content_page.dart
class iCubeTestPage extends StatefulWidget {
  final bool selectionMode;
  final String? managerId;
  final String? experienceId;
  final List<String>? initialSelectedContents;

  const iCubeTestPage({
    super.key,
    this.selectionMode = false,
    this.managerId,
    this.experienceId,
    this.initialSelectedContents,
  });

  @override
  State<iCubeTestPage> createState() => _iCubeTestPageState();
}

class _iCubeTestPageState extends State<iCubeTestPage> {
  List<dynamic> contents = [];
  bool isLoading = true;
  String? errorMessage;
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
      grouped.putIfAbsent(tag, () => []);
      grouped[tag]!.add(content);
    }

    final sortedGroups = <String, List<dynamic>>{};
    for (var tag in tagOrder) {
      if (grouped.containsKey(tag)) {
        sortedGroups[tag] = grouped[tag]!;
      }
    }
    // Add remaining tags (unsorted)
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

    // Pre-load selected contents
    if (widget.initialSelectedContents != null &&
        widget.initialSelectedContents!.isNotEmpty) {
      selectedContents = Set<String>.from(widget.initialSelectedContents!);
    } else if (widget.managerId != null && widget.experienceId != null) {
      _loadSelectedContents();
    }

    fetchContents();
  }

  Future<void> _loadSelectedContents() async {
    if (widget.managerId == null || widget.experienceId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .collection('ManagerContentSelections')
          .doc('icube_${widget.managerId}')
          .get();

      if (doc.exists) {
        final selection = ManagerContentSelection.fromDoc(doc);
        setState(() {
          selectedContents = Set<String>.from(selection.selectedContents);
        });
      }
    } catch (_) {
      // Silent ignore
    }
  }

  Future<void> _saveSelectedContents() async {
    if (widget.managerId == null || widget.experienceId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .set({}, SetOptions(merge: true));

      final selection = ManagerContentSelection(
        id: 'icube_${widget.managerId}',
        managerId: widget.managerId!,
        device: 'iCube',
        experienceId: widget.experienceId!,
        selectedContents: selectedContents.toList(),
      );

      await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .collection('ManagerContentSelections')
          .doc(selection.id)
          .set(selection.toMap());
    } catch (_) {
      // Silent ignore
    }
  }

  Future<void> fetchContents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await DeviceLoadingService.fetchICubeContents();

      if (result.error != null) {
        setState(() {
          errorMessage = result.error;
          isLoading = false;
        });
        return;
      }

      final contentsList = result.contents;

      // Fetch tags
      for (var content in contentsList) {
        if (content['has_tag'] == true && content['tag_url'] != null) {
          try {
            final tagResponse = await http
                .get(
                  Uri.parse(
                    '${DeviceLoadingService.getBaseUrl('iCube')}${content['tag_url']}',
                  ),
                )
                .timeout(requestTimeout);

            if (tagResponse.statusCode == 200) {
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
    } catch (e) {
      setState(() {
        errorMessage = 'Please connect to Digital_Dream_2_5G wifi.';
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Widget> _buildContentSections() {
    final groupedContents = groupAndSortContents();
    final sections = <Widget>[];

    for (var tag in groupedContents.keys) {
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 0.0, bottom: 12.0),
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

      sections.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
            final contentName = content['name'];
            final isSelected = selectedContents.contains(contentName);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedContents.remove(contentName);
                  } else {
                    selectedContents.add(contentName);
                  }
                });
              },
              child: Card(
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
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              DeviceLoadingService.getContentIconUrl(
                                'iCube',
                                content['icon_url'] ?? '',
                              ),
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
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.black.withOpacity(0.5),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        contentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      sections.add(const SizedBox(height: 60.0));
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionMode ? 'Add iCube Content' : 'iCube Contents',
        ),
        backgroundColor: const Color.fromRGBO(143, 148, 251, 1),
        foregroundColor: Colors.white,
        actions: widget.selectionMode
            ? [
                TextButton(
                  onPressed: () async {
                    await _saveSelectedContents();
                    if (mounted) {
                      Navigator.pop(context, selectedContents.toList());
                    }
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          // iCUBE Logo at the top
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Image.network(
              'https://firebasestorage.googleapis.com/v0/b/ddapp-c89cb.firebasestorage.app/o/digitaldream_logos%2Ficube_logo.png?alt=media&token=18ccca3e-3923-469e-b2e8-e3a48157cc85',
              height: 120,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: fetchContents,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(
                                143,
                                148,
                                251,
                                1,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
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
                      // Content sections
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
          ),
        ],
      ),
    );
  }
}
