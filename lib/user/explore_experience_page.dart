import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/manager/add_icubecontent_page.dart';
import 'package:cloudd_flutter/manager/add_irigcontent_page.dart';
import 'package:cloudd_flutter/webapp_access_page.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/services/recently_played_service.dart';
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

  Map<String, String?> runningContent = {};
  final Map<String, DateTime?> runningStart = {};
  final Map<String, String?> runningRecentDocId = {};
  final Map<String, DateTime?> _lastStateUpdateTime = {};
  static const Duration _pollDebounce = Duration(milliseconds: 1000);

  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  final List<String> devices = ['iCube', 'iRig', 'iCreate', 'Storytime'];
  String? _selectedDevice;

  String? _currentDeviceIP;
  final Map<String, String?> _queuedContentByDevice = {};
  final Map<String, bool> _isAutoLaunchActiveByDevice = {};
  bool _isRunningStatusPolling = false;

  @override
  void initState() {
    super.initState();
    _selectedDevice = devices.first; // Select first device by default
    // Initialize queue tracking for all devices
    for (final device in devices) {
      _queuedContentByDevice[device] = null;
      _isAutoLaunchActiveByDevice[device] = false;
    }
    _loadAllData();
    _getCurrentDeviceIP();
    _startRunningStatusPolling();
  }

  Future<void> _getCurrentDeviceIP() async {
    try {
      // Call the dedicated /client_ip endpoint to establish our device's identity
      final result = await DeviceLoadingService.getClientIP('iCube');
      if (result.error == null && result.clientIP != null) {
        setState(() {
          _currentDeviceIP = result.clientIP;
        });
      }
    } catch (e) {
      debugPrint('Error getting device IP: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    // Stop all auto-launch monitors
    for (final device in devices) {
      _isAutoLaunchActiveByDevice[device] = false;
    }
    _isRunningStatusPolling = false;
    super.dispose();
  }

  void _startRunningStatusPolling() {
    if (_isRunningStatusPolling) return;
    _isRunningStatusPolling = true;
    _pollRunningStatus();
  }

  Future<void> _pollRunningStatus() async {
    while (_isRunningStatusPolling && mounted) {
      try {
        final Map<String, String?> latestRunning = {};

        // Fetch statuses in parallel for faster UI updates
        await Future.wait(
          devices.map((device) async {
            final status = await DeviceLoadingService.checkLaunchedClientIP(
              device,
            );

            // Only track content started from this client; ignore others
            if (_currentDeviceIP != null &&
                status.clientIP != null &&
                status.clientIP != _currentDeviceIP) {
              latestRunning[device] = null;
            } else if (status.status == 'content_running') {
              latestRunning[device] = status.runningContent;
            } else {
              latestRunning[device] = null;
            }
          }),
        );

        if (mounted && _isRunningStatusPolling) {
          setState(() {
            for (final entry in latestRunning.entries) {
              // Skip updating if we recently made a local state change to this device
              // to prevent flashing/flickering from rapid polling updates
              final lastUpdate = _lastStateUpdateTime[entry.key];
              if (lastUpdate != null &&
                  DateTime.now().difference(lastUpdate) < _pollDebounce) {
                continue;
              }
              runningContent[entry.key] = entry.value;
            }
          });
        }

        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('Error polling running status: $e');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _startAutoLaunchMonitor(String device, String contentName) {
    _queuedContentByDevice[device] = contentName;
    _isAutoLaunchActiveByDevice[device] = true;
    _checkAndLaunchWhenTurn(device);
  }

  void _checkAndLaunchWhenTurn(String device) {
    if (_isAutoLaunchActiveByDevice[device] != true ||
        _queuedContentByDevice[device] == null) {
      return;
    }

    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted || _isAutoLaunchActiveByDevice[device] != true) return;

      try {
        final positionResult = await DeviceLoadingService.getQueuePosition(
          device,
        );

        if (!mounted || _isAutoLaunchActiveByDevice[device] != true) return;

        if (positionResult.queuePosition == 0) {
          // User's turn! Auto-launch the content
          _isAutoLaunchActiveByDevice[device] = false;
          await launchContent(device, _queuedContentByDevice[device]!);
          // Don't clear the queued content here, let the user manually dequeue after
        } else {
          // Not yet user's turn, check again soon
          _checkAndLaunchWhenTurn(device);
        }
      } catch (e) {
        debugPrint('Error checking queue position: $e');
        if (_isAutoLaunchActiveByDevice[device] == true && mounted) {
          // Retry on error
          _checkAndLaunchWhenTurn(device);
        }
      }
    });
  }

  Future<void> _refreshQueueState() async {
    // Check queue positions for all devices and clear stale entries
    for (final device in devices) {
      if (_queuedContentByDevice[device] != null) {
        try {
          final positionResult = await DeviceLoadingService.getQueuePosition(
            device,
          );
          // If not in queue anymore (position -1), clear the queued content
          if (positionResult.queuePosition == -1) {
            setState(() {
              _queuedContentByDevice[device] = null;
              _isAutoLaunchActiveByDevice[device] = false;
            });
          }
        } catch (e) {
          debugPrint('Error checking queue position for $device: $e');
        }
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

    // Not using fetch all contents function because it will batch load, and make it slower
    // So loading will be parallel instead, which allows each device section to display as soon as their data arrives
    final futures = <Future<void>>[];

    futures.add(_fetchDeviceContent('iCube'));
    futures.add(_fetchDeviceContent('iCreate'));
    futures.add(_fetchDeviceContent('iRig'));
    futures.add(_fetchDeviceContent('Storytime'));

    // Wait for all to complete, but each updates UI independently
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

      setState(() {
        deviceContents[device] = result;
        deviceLoading[device] = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        deviceLoading[device] = false;
      });
      debugPrint('Error loading $device: $e');
    }
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

  // Logic of launchContent simplified:
  // First checks if there is any content running on the device
  // If there is content running and the client IP matches the user's device IP, then when the user presses play
  // for another content in same device, it will stop the previous content and launch the new one

  // but if there is content running and the client IP does NOT match the user's device IP,
  // then it shows the "Device in Use" pop up and doesnt launch the content

  Future<void> launchContent(
    String device,
    String contentName, {
    String? boothName,
    String? logoUrl,
  }) async {
    // First, establish our device IP if we don't have it yet
    // This ensures we know what IP we're launching from before checking device status
    if (_currentDeviceIP == null) {
      // Make a dummy call to the server to establish our IP
      try {
        await DeviceLoadingService.checkLaunchedClientIP(device);
        // After this call, the server knows our IP, even if no content is running
        // We'll get our actual IP confirmed after the first successful launch
      } catch (e) {
        debugPrint('Error establishing device IP: $e');
      }
    }

    // Check the device's client IP status
    final clientIPResult = await DeviceLoadingService.checkLaunchedClientIP(
      device,
    );

    // If there's content running, check if its from another client
    if (clientIPResult.status == 'content_running' &&
        clientIPResult.clientIP != null) {
      // If we still don't have our own IP, establish it now by comparing
      if (_currentDeviceIP == null) {
        _currentDeviceIP = clientIPResult.clientIP;
      }

      // Check if someone else is using the device by comparing IPs
      if (clientIPResult.clientIP != _currentDeviceIP) {
        if (!mounted) return;
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
                  // Enqueue to the Flask API
                  try {
                    final result = await DeviceLoadingService.enqueueDevice(
                      device,
                    );
                    if (result.success) {
                      // Start monitoring for when it's user's turn
                      _startAutoLaunchMonitor(device, contentName);
                    }
                  } catch (e) {
                    debugPrint('Error enqueuing: $e');
                  }

                  if (!mounted) return;
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QueueingPage(
                        device: device,
                        contentName: contentName,
                        queuedContentMap: Map<String, String?>.from(
                          _queuedContentByDevice,
                        ),
                      ),
                    ),
                  );
                  // Refresh queue state after returning
                  await _refreshQueueState();
                },
                child: const Text('Add to queue'),
              ),
            ],
          ),
        );
        return;
      }

      // If we're here it means own content running
      // Stop the current content before launching new one
      if (clientIPResult.runningContent != null &&
          clientIPResult.runningContent != contentName) {
        await stopContent(device, clientIPResult.runningContent!);
      }
    }

    // Also handle local tracking
    if (runningContent[device] != null &&
        runningContent[device] != contentName) {
      await stopContent(device, runningContent[device]!);
    }

    final result = await DeviceLoadingService.launchContent(
      device,
      contentName,
    );
    if (!mounted) return;

    if (result.success) {
      setState(() {
        runningContent[device] = contentName;
        _lastStateUpdateTime[device] = DateTime.now();
      });

      // Update our device IP after successful launch - this confirms our actual IP
      if (_currentDeviceIP == null) {
        _getCurrentDeviceIP();
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final docId = await RecentlyPlayedService.addRecentlyPlayed(
            userId: uid,
            device: device,
            boothName: boothName ?? contentName,
            experienceId: widget.experienceId,
            experienceName: experience?.name ?? widget.experienceName,
            logoUrl: logoUrl,
          );
          runningStart[device] = DateTime.now();
          runningRecentDocId[device] = docId;
        } catch (e) {
          debugPrint('RecentlyPlayed error: $e');
        }
      }

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

  Future<void> stopContent(String device, String contentName) async {
    final result = await DeviceLoadingService.stopContent(device, contentName);
    if (!mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final start = runningStart[device];
    final docId = runningRecentDocId[device];

    if (uid != null && start != null && docId != null) {
      final seconds = DateTime.now().difference(start).inSeconds;
      await RecentlyPlayedService.updatePlaytimeByDocId(
        userId: uid,
        docId: docId,
        seconds: seconds,
      );
    }

    setState(() {
      runningContent[device] = null;
      _lastStateUpdateTime[device] = DateTime.now();
      runningStart.remove(device);
      runningRecentDocId.remove(device);
      // If the stopped content was queued, clear it from queue tracking
      if (_queuedContentByDevice[device] == contentName) {
        _queuedContentByDevice[device] = null;
        _isAutoLaunchActiveByDevice[device] = false;
      }
    });

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
    final isRunning = runningContent[device] == contentName;
    final isQueued = _queuedContentByDevice[device] == contentName;

    final buttonSize = const Size(110, 40);
    const stopIconSize = 20.0;
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
                fit: StackFit.expand,
                children: [
                  if (iconUrl != null)
                    Image.network(
                      iconUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
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
                    onPressed: () => stopContent(device, contentName!),
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
                          builder: (_) => QueueingPage(
                            device: device,
                            contentName: contentName,
                          ),
                        ),
                      );
                      // Refresh queue state after returning
                      await _refreshQueueState();
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
                        launchContent(
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
                      backgroundColor: const Color.fromRGBO(143, 148, 251, 1),
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
  }

  Widget _buildSection(String title, String deviceName, String keyword) {
    final isDeviceLoading = deviceLoading[deviceName] ?? false;

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

    // Show loading only for this specific device section
    if (isDeviceLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return WillPopScope(
      onWillPop: () async {
        final hasRunning = runningContent.values.any(
          (v) => v != null && v.isNotEmpty,
        );
        final hasQueued = _queuedContentByDevice.values.any(
          (v) => v != null && v.isNotEmpty,
        );

        // Check if user is in a queue
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
          return false;
        }

        if (!hasRunning) return true;

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
          for (final entry in runningContent.entries.where(
            (e) => e.value != null,
          )) {
            await stopContent(entry.key, entry.value!);
          }
          return true;
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Explore: $displayName'),
          actions: [
            TextButton(
              onPressed: () async {
                // Pass all queued content to QueueingPage
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QueueingPage(
                      queuedContentMap: Map<String, String?>.from(
                        _queuedContentByDevice,
                      ),
                    ),
                  ),
                );
                // Refresh queue state after returning
                await _refreshQueueState();
              },
              child: const Text(
                'View queue',
                style: TextStyle(color: Colors.white),
              ),
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
                      isSignedUp ? 'Cancel Sign Up' : 'Sign Up for Experience',
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
                // Device icons horizontally
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
                                  // color: isSelected
                                  //     ? Colors.transparent
                                  //     : Colors.transparent,
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
  }
}
