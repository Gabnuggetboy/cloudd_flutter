import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloudd_flutter/manager/add_icubecontent_page.dart';
import 'package:cloudd_flutter/manager/add_irigcontent_page.dart';
import 'package:cloudd_flutter/webapp_access_page.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/services/image_caching_service.dart';
import 'package:cloudd_flutter/services/queue_service.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/user/queueing_page.dart';

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
  Experience? experience;
  bool experienceLoading = true;
  String? experienceError;

  final Map<String, DeviceContentResult> deviceContents = {};
  final Map<String, bool> deviceLoading = {
    'iCube': true,
    'iCreate': true,
    'iRig': true,
    'Storytime': true,
  };
  final Map<String, bool> deviceOffline = {
    'iCube': false,
    'iCreate': false,
    'iRig': false,
    'Storytime': false,
  };

  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  final List<String> devices = QueueService.devices;
  String? _selectedDevice;

  bool _isRunningStatusPolling = false;

  @override
  void initState() {
    super.initState();
    _selectedDevice = devices.first;
    _loadAllData();
    _startRunningStatusPolling();
  }

  @override
  void dispose() {
    searchController.dispose();
    _isRunningStatusPolling = false;
    super.dispose();
  }

  void _startRunningStatusPolling() {
    if (_isRunningStatusPolling) return;
    _isRunningStatusPolling = true;
    _pollRunningStatus();
  }

  Future<void> _pollRunningStatus() async {
    final queueService = QueueService();
    while (_isRunningStatusPolling && mounted) {
      try {
        await queueService.pollAllDevicesRunningStatus();
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Error polling running status: $e');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Stream<QuerySnapshot> signupStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('experience_signups')
        .where('experienceId', isEqualTo: widget.experienceId)
        .where('userId', isEqualTo: user.uid)
        .limit(1)
        .snapshots();
  }

  Future<void> signUp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('experience_signups').add({
      'experienceId': widget.experienceId,
      'experienceName': widget.experienceName,
      'userId': user.uid,
      'userEmail': user.email,
      'signedAt': Timestamp.now(),
    });
  }

  Future<void> cancelSignUp(String docId) async {
    await FirebaseFirestore.instance
        .collection('experience_signups')
        .doc(docId)
        .delete();
  }

  Future<void> _loadAllData() async {
    _fetchExperience();

    final futures = <Future<void>>[];
    futures.add(_fetchDeviceContent('iCube'));
    futures.add(_fetchDeviceContent('iCreate'));
    futures.add(_fetchDeviceContent('iRig'));
    futures.add(_fetchDeviceContent('Storytime'));

    await Future.wait(futures);
  }

  Future<void> _fetchDeviceContent(String device) async {
    if (!mounted) return;

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

      if (!mounted) return;

      // Check if the result has an error (device offline or failed to load)
      final bool isOffline =
          result.error != null && _isDeviceOfflineError(result.error!);

      setState(() {
        deviceContents[device] = result;
        deviceLoading[device] = false;
        deviceOffline[device] = isOffline;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        deviceLoading[device] = false;
        deviceOffline[device] = _isDeviceOfflineError(e.toString());
      });
      debugPrint('Error loading $device: $e');
    }
  }

  // Check if an error message indicates the device is offline
  bool _isDeviceOfflineError(String message) {
    final lowerMessage = message.toLowerCase();
    return lowerMessage.contains('timeout') ||
        lowerMessage.contains('timed out') ||
        lowerMessage.contains('connection refused') ||
        lowerMessage.contains('connection failed') ||
        lowerMessage.contains('socketexception') ||
        lowerMessage.contains('no route to host') ||
        lowerMessage.contains('network is unreachable') ||
        lowerMessage.contains('host unreachable') ||
        lowerMessage.contains('failed host lookup');
  }

  Future<void> _fetchExperience() async {
    setState(() {
      experienceLoading = true;
      experienceError = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .get();

      if (!doc.exists) {
        setState(() {
          experienceError = 'Experience not found';
          experience = null;
        });
      } else {
        setState(() {
          experience = Experience.fromDoc(doc);
          experienceError = null;
        });
      }
    } catch (e) {
      setState(() {
        experienceError = 'Failed to load experience: $e';
        experience = null;
      });
    } finally {
      if (mounted) {
        setState(() => experienceLoading = false);
      }
    }
  }

  Future<void> _handleLaunchContent(
    String device,
    String contentName, {
    String? boothName,
    String? logoUrl,
  }) async {
    final queueService = context.read<QueueService>();

    final result = await queueService.launchContent(
      device,
      contentName,
      boothName: boothName,
      logoUrl: logoUrl,
      experienceId: widget.experienceId,
      experienceName: experience?.name ?? widget.experienceName,
    );

    if (!mounted) return;

    if (result.deviceInUse) {
      // Show "Device in Use" dialog with queue option
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('$device In Use'),
          content: Text('Somebody else is using $device'),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              onPressed: () async {
                final success = await queueService.enqueue(
                  device,
                  contentName,
                  boothName: boothName ?? contentName,
                  logoUrl: logoUrl,
                );

                if (!mounted) return;
                Navigator.pop(context);

                if (success) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QueueingPage(device: device),
                    ),
                  );
                  await queueService.refreshQueueState();
                }
              },
              child: const Text('Add to queue'),
            ),
          ],
        ),
      );
    } else if (result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));

      if (device == 'Storytime') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StoryTimeWebappPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleStopContent(String device, String contentName) async {
    final queueService = context.read<QueueService>();
    final result = await queueService.stopContent(device, contentName);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : Colors.red,
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.vrpano, size: 80, color: Colors.black54),
      ),
    );
  }

  Widget _buildScalableTitle(String title) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBoothCard(Map<String, dynamic> booth) {
    final deviceRaw = (booth['device'] ?? '').toString().toLowerCase();
    final device = deviceRaw.contains('icube')
        ? 'iCube'
        : deviceRaw.contains('irig')
        ? 'iRig'
        : deviceRaw.contains('icreate')
        ? 'iCreate'
        : deviceRaw.contains('storytime')
        ? 'Storytime'
        : '';

    final contentName = booth['contentName'] as String?;
    final result = deviceContents[device];
    final contents = result?.contents ?? [];
    final matched = contentName != null
        ? contents.cast<Map<String, dynamic>>().firstWhere(
            (c) => c['name'] == contentName,
            orElse: () => <String, dynamic>{},
          )
        : null;

    final baseUrl = DeviceLoadingService.getBaseUrl(device);
    final iconUrl = matched?['icon_url'] != null
        ? '$baseUrl${matched!['icon_url']}'
        : booth['icon_url'] != null && (booth['icon_url'] as String).isNotEmpty
        ? '$baseUrl${booth['icon_url']}'
        : null;

    final title = contentName ?? device;

    return Consumer<QueueService>(
      builder: (context, queueService, child) {
        final state = queueService.getDeviceState(device);
        final currentClientIP = queueService.currentClientIP;
        // Only show as running if it's THIS user's content (matching client IP)
        final isRunningByThisUser =
            state.runningContent == contentName &&
            currentClientIP != null &&
            state.runningClientIP == currentClientIP;
        final isRunning = isRunningByThisUser;
        final isQueued = state.queuedContent == contentName;

        final buttonSize = const Size(110, 40);
        const stopIconSize = 20.0;

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
                    fit: StackFit.expand,
                    children: [
                      if (iconUrl != null)
                        ImageCacheService().getCachedImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.cover,
                          errorWidget: _buildFallbackIcon(),
                        )
                      else
                        _buildFallbackIcon(),
                      if (isRunning)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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
                  children: [
                    _buildScalableTitle(title),
                    const SizedBox(height: 8),
                    if (isRunning)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _handleStopContent(device, contentName!),
                        icon: const Icon(Icons.stop_circle, size: stopIconSize),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: buttonSize,
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else if (isQueued)
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QueueingPage(device: device),
                            ),
                          );
                          await queueService.refreshQueueState();
                        },
                        icon: const Icon(Icons.queue, size: stopIconSize),
                        label: const Text(
                          'In Queue',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: buttonSize,
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          if (contentName != null) {
                            _handleLaunchContent(
                              device,
                              contentName,
                              boothName: contentName,
                              logoUrl: matched?['icon_url'] != null
                                  ? '$baseUrl${matched!['icon_url']}'
                                  : null,
                            );
                          } else {
                            if (device == 'iCube') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      iCubeTestPage(selectionMode: false),
                                ),
                              );
                            } else if (device == 'iRig') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      IrigTestPage(selectionMode: false),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: buttonSize,
                          backgroundColor: const Color.fromRGBO(
                            143,
                            148,
                            251,
                            1,
                          ),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(contentName != null ? 'Play' : 'Open'),
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

  Widget _buildSection(String title, String deviceName, String keyword) {
    final isDeviceLoading = deviceLoading[deviceName] ?? false;
    final isDeviceOffline = deviceOffline[deviceName] ?? false;

    if (experienceLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (experienceError != null) {
      return Center(child: Text(experienceError!));
    }
    if (experience == null) {
      return const Center(child: Text('No experience loaded'));
    }

    final booths = experience!.booths
        .where(
          (b) => (b['device'] ?? '').toString().toLowerCase().contains(keyword),
        )
        .toList();

    final filtered = searchQuery.trim().isEmpty
        ? booths
        : booths.where((b) {
            final name = (b['contentName'] ?? '').toString().toLowerCase();
            return name.contains(searchQuery.toLowerCase());
          }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No booths available'));
    }

    if (isDeviceLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isDeviceOffline) {
      return const Center(
        child: Text(
          'Device is offline',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
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
      itemBuilder: (_, i) => _buildBoothCard(Map.from(filtered[i])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = experience?.name ?? widget.experienceName;
    final theme = Theme.of(context);
    final appBarActionColor =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return Consumer<QueueService>(
      builder: (context, queueService, child) {
        final currentClientIP = queueService.currentClientIP;
        // Only consider content as "running" if it belongs to THIS user
        final hasRunning = QueueService.devices.any((d) {
          final state = queueService.getDeviceState(d);
          return state.runningContent != null &&
              currentClientIP != null &&
              state.runningClientIP == currentClientIP;
        });
        final hasQueued = QueueService.devices.any(
          (d) => queueService.getQueuedContent(d) != null,
        );

        return PopScope(
          canPop: !hasRunning && !hasQueued,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            if (hasQueued) {
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('In Queue'),
                  content: const Text(
                    'You are currently in a queue. Please remove yourself from the queue before exiting.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              return;
            }

            if (hasRunning) {
              final stopAll = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Content Running'),
                  content: const Text('Please stop all content before exiting'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Stop all',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (stopAll == true) {
                for (final device in QueueService.devices) {
                  final state = queueService.getDeviceState(device);
                  // Only stop content that belongs to THIS user
                  if (state.runningContent != null &&
                      currentClientIP != null &&
                      state.runningClientIP == currentClientIP) {
                    await queueService.stopContent(
                      device,
                      state.runningContent!,
                    );
                  }
                }
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text('Explore: $displayName'),
              actions: [
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QueueingPage()),
                    );
                    await queueService.refreshQueueState();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: appBarActionColor,
                  ),
                  child: const Text('View queue'),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: StreamBuilder<QuerySnapshot>(
                  stream: signupStream(),
                  builder: (context, snapshot) {
                    final isSignedUp =
                        snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                    final signupDocId = isSignedUp
                        ? snapshot.data!.docs.first.id
                        : null;

                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (isSignedUp) {
                            await cancelSignUp(signupDocId!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Signup cancelled')),
                            );
                          } else {
                            await signUp();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Successfully signed up'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSignedUp
                              ? Colors.red
                              : const Color.fromRGBO(143, 148, 251, 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          isSignedUp
                              ? 'Cancel Sign Up'
                              : 'Sign Up for Experience',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: _loadAllData,
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
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
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
                                      child: ImageCacheService().getCachedImage(
                                        imageUrl: DeviceLoadingService
                                            .deviceLogos[device]!,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.contain,
                                        errorWidget: Container(
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
                                        ),
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
                      _buildSection(
                        '${_selectedDevice!} Contents',
                        _selectedDevice!,
                        _selectedDevice == 'iCube'
                            ? 'icube'
                            : _selectedDevice == 'iCreate'
                            ? 'icreate'
                            : _selectedDevice == 'iRig'
                            ? 'irig'
                            : 'storytime',
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
