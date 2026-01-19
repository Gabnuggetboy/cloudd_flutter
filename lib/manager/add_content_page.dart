import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cloudd_flutter/services/device_loading_service.dart';

class AddContentPage extends StatefulWidget {
  final bool selectionMode;
  final String? managerId;
  final String? experienceId;
  final Map<String, List<String>>? initialSelectedByDevice;

  const AddContentPage({
    super.key,
    this.selectionMode = true,
    this.managerId,
    this.experienceId,
    this.initialSelectedByDevice,
  });

  @override
  State<AddContentPage> createState() => _AddContentPageState();
}

class _AddContentPageState extends State<AddContentPage> {
  final List<String> devices = ['iCube', 'iRig', 'iCreate', 'Storytime'];

  String? _selectedDevice;
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  final Map<String, DeviceContentResult> deviceContents = {};
  final Map<String, bool> deviceLoading = {
    'iCube': true,
    'iCreate': true,
    'iRig': true,
    'Storytime': true,
  };
  final Map<String, String?> deviceError = {
    'iCube': null,
    'iCreate': null,
    'iRig': null,
    'Storytime': null,
  };

  final Map<String, Set<String>> selectedByDevice = {
    'iCube': <String>{},
    'iCreate': <String>{},
    'iRig': <String>{},
    'Storytime': <String>{},
  };

  // iCube tags order
  final List<String> tagOrder = const [
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

  @override
  void initState() {
    super.initState();
    _selectedDevice = devices.first;

    // Seed initial selections
    final initial = widget.initialSelectedByDevice;
    if (initial != null) {
      for (final entry in initial.entries) {
        if (selectedByDevice.containsKey(entry.key)) {
          selectedByDevice[entry.key] = entry.value.toSet();
        }
      }
    } else if (widget.managerId != null && widget.experienceId != null) {
      _loadSelectedContentsFromFirestore();
    }

    _loadAllContentsParallel();
  }

  Future<void> _loadSelectedContentsFromFirestore() async {
    try {
      final expId = widget.experienceId!;
      final mgrId = widget.managerId!;
      final fs = FirebaseFirestore.instance;

      // Firestore doc IDs per device (match existing pages)
      final ids = {
        'iCube': 'icube_$mgrId',
        'iRig': 'irig_$mgrId',
        'iCreate': 'icreate$mgrId', // note: no underscore as per existing page
        'Storytime': 'storytime_$mgrId',
      };

      await Future.wait(
        devices.map((device) async {
          try {
            final doc = await fs
                .collection('Experiences')
                .doc(expId)
                .collection('ManagerContentSelections')
                .doc(ids[device]!)
                .get();
            if (doc.exists) {
              final data = doc.data();
              final list = (data?['selectedContents'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();
              selectedByDevice[device] = list.toSet();
            }
          } catch (_) {}
        }),
      );
    } catch (_) {}
  }

  Future<void> _loadAllContentsParallel() async {
    final futures = <Future<void>>[];
    futures.add(_fetchDeviceContent('iCube'));
    futures.add(_fetchDeviceContent('iCreate'));
    futures.add(_fetchDeviceContent('iRig'));
    futures.add(_fetchDeviceContent('Storytime'));
    await Future.wait(futures);
  }

  Future<void> _fetchDeviceContent(String device) async {
    try {
      DeviceContentResult result;
      switch (device) {
        case 'iCube':
          result = await DeviceLoadingService.fetchICubeContents();
          break;
        case 'iRig':
          result = await DeviceLoadingService.fetchIRigContents();
          break;
        case 'iCreate':
          result = await DeviceLoadingService.fetchICreateContents();
          break;
        case 'Storytime':
          result = await DeviceLoadingService.fetchStorytimeContents();
          break;
        default:
          return;
      }

      // For iCube, fetch tags for each content item in parallel
      if (device == 'iCube' && result.error == null) {
        final contentsList = result.contents;

        // Create list of futures for parallel execution
        final tagFutures = contentsList.map((content) async {
          if (content['has_tag'] == true && content['tag_url'] != null) {
            try {
              final tagResponse = await http
                  .get(
                    Uri.parse(
                      '${DeviceLoadingService.getBaseUrl('iCube')}${content['tag_url']}',
                    ),
                  )
                  .timeout(const Duration(seconds: 5));

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
        }).toList();

        // Wait for all tag requests to complete in parallel
        await Future.wait(tagFutures);
        result = DeviceContentResult(contents: contentsList, error: null);
      }

      if (!mounted) return;
      setState(() {
        deviceContents[device] = result;
        deviceLoading[device] = false;
        deviceError[device] = result.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        deviceLoading[device] = false;
        deviceError[device] = 'Please connect to Digital_Dream_2_5G wifi.';
      });
    }
  }

  void _toggleSelection(String device, String name) {
    final set = selectedByDevice[device] ?? <String>{};
    set.contains(name) ? set.remove(name) : set.add(name);
    setState(() => selectedByDevice[device] = set);
  }

  Future<void> _saveSelections() async {
    if (widget.managerId == null || widget.experienceId == null) return;

    final fs = FirebaseFirestore.instance;
    final expId = widget.experienceId!;
    final mgrId = widget.managerId!;

    // Ensure parent exists
    await fs
        .collection('Experiences')
        .doc(expId)
        .set({}, SetOptions(merge: true));

    final ids = {
      'iCube': 'icube',
      'iRig': 'irig',
      'iCreate': 'icreate',
      'Storytime': 'storytime',
    };

    await Future.wait(
      devices.map((device) async {
        final list = selectedByDevice[device]!.toList();
        final payload = {
          'id': ids[device],
          'managerId': mgrId,
          'device': device,
          'experienceId': expId,
          'selectedContents': list,
        };
        await fs
            .collection('Experiences')
            .doc(expId)
            .collection('ManagerContentSelections')
            .doc(ids[device]!)
            .set(payload);
      }),
    );
  }

  Map<String, List<String>> _buildResultMap() {
    return devices.asMap().map(
      (_, device) => MapEntry(device, selectedByDevice[device]!.toList()),
    );
  }

  Widget _buildFallbackThumb() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.vrpano, size: 48, color: Colors.black54),
      ),
    );
  }

  Widget _buildContentTile(String device, Map<String, dynamic> content) {
    final name = (content['name'] ?? '').toString();
    final iconPath = (content['icon_url'] ?? '').toString();
    final iconUrl = iconPath.isNotEmpty
        ? DeviceLoadingService.getContentIconUrl(device, iconPath)
        : null;
    final selected = selectedByDevice[device]!.contains(name);

    return GestureDetector(
      onTap: () => _toggleSelection(device, name),
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
                  fit: StackFit.expand,
                  children: [
                    if (iconUrl != null)
                      Image.network(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackThumb(),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                      )
                    else
                      _buildFallbackThumb(),
                    if (selected)
                      Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
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
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<dynamic>> _groupICubeByTag(List<dynamic> contents) {
    final grouped = <String, List<dynamic>>{};
    for (final c in contents) {
      final tag = (c['tag'] ?? 'Other').toString();
      grouped.putIfAbsent(tag, () => []);
      grouped[tag]!.add(c);
    }
    final sorted = <String, List<dynamic>>{};
    for (final t in tagOrder) {
      if (grouped.containsKey(t)) sorted[t] = grouped[t]!;
    }
    // Append remaining
    for (final t in grouped.keys) {
      if (!sorted.containsKey(t)) sorted[t] = grouped[t]!;
    }
    return sorted;
  }

  Widget _buildDeviceGrid(String device) {
    final isLoading = deviceLoading[device] ?? true;
    final error = deviceError[device];
    final result = deviceContents[device];
    final contents = result?.contents ?? const [];

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error));
    }
    final filtered = searchQuery.trim().isEmpty
        ? contents
        : contents.where((c) {
            final name = (c['name'] ?? '').toString().toLowerCase();
            final tag = (c['tag'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery.toLowerCase()) ||
                tag.contains(searchQuery.toLowerCase());
          }).toList();

    if (device == 'iCube') {
      final grouped = _groupICubeByTag(filtered);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: entry.value.length,
                itemBuilder: (_, i) => _buildContentTile(
                  device,
                  Map<String, dynamic>.from(entry.value[i] as Map),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        }).toList(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _buildContentTile(
        device,
        Map<String, dynamic>.from(filtered[i] as Map),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Content'),
        actions: [
          TextButton(
            onPressed: () async {
              await _saveSelections();
              if (!mounted) return;
              Navigator.pop(context, _buildResultMap());
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllContentsParallel,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 5),
                // Device icons horizontally (matches ExploreExperiencePage)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.0),
                      child: Row(
                        children: devices.map((device) {
                          final isSelected = _selectedDevice == device;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDevice = device;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(
                                          color: const Color.fromARGB(
                                            255,
                                            168,
                                            171,
                                            228,
                                          ),
                                          width: 3,
                                        )
                                      : null,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    DeviceLoadingService.deviceLogos[device]!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 64,
                                        height: 64,
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: Icon(
                                            Icons.vrpano,
                                            size: 32,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_selectedDevice == null)
                  const Center(
                    child: Text(
                      'Select a device to view contents',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                else ...[
                  _buildDeviceGrid(_selectedDevice!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
