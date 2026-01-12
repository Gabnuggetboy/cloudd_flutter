import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  final Map<String, String> deviceKeywords = {
    'iCube': 'icube',
    'iCreate': 'icreate',
    'iRig': 'irig',
    'Storytime': 'storytime',
  };

  String? _currentDeviceIP;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _getCurrentDeviceIP();
  }

  Future<void> _getCurrentDeviceIP() async {
    try {
      // Get IP from any device endpoint, they should all see the same client IP
      final result = await DeviceLoadingService.checkLaunchedClientIP('iCube');
      if (result.error == null && result.clientIP != null) {
        // If there's a running content, we got the IP from that
        setState(() {
          _currentDeviceIP = result.clientIP;
        });
      }
      // If no content is running then get the IP when we first launch something
    } catch (e) {
      debugPrint('Error getting device IP: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

    await FirebaseFirestore.instance
        .collection('experience_signups')
        .add({
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
    // Check the device's client IP status
    final clientIPResult = await DeviceLoadingService.checkLaunchedClientIP(
      device,
    );

    // If there's content running, check if it's from another client
    if (clientIPResult.status == 'content_running' &&
        clientIPResult.clientIP != null) {
      // Store the client device IP if we don't have it yet
      if (_currentDeviceIP == null && clientIPResult.clientIP != null) {
        _currentDeviceIP = clientIPResult.clientIP;
      }

      // Check if someone else is using the device
      // We compare IPs only if we have our own IP established
      if (_currentDeviceIP != null &&
          clientIPResult.clientIP != _currentDeviceIP) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('$device In Use'),
            content: const Text('Somebody else is using this device'),
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

      // If we're here, either it's our content running or IPs match
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
      setState(() => runningContent[device] = contentName);

      // Update our device IP after successful launch
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
      runningStart.remove(device);
      runningRecentDocId.remove(device);
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
        appBar: AppBar(title: Text('Explore: $displayName')),
         bottomNavigationBar: SafeArea(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: StreamBuilder<QuerySnapshot>(
      stream: signupStream(),
      builder: (context, snapshot) {
        final isSignedUp =
            snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        final signupDocId =
            isSignedUp ? snapshot.data!.docs.first.id : null;

        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () async {
              if (isSignedUp) {
                await cancelSignUp(signupDocId!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Signup cancelled'),
                  ),
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
              backgroundColor:
                  isSignedUp ? Colors.red : const Color.fromRGBO(143, 148, 251, 1),
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
                const SizedBox(height: 16),
                const Text(
                  'iCube',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildSection('iCube', 'iCube', 'icube'),
                const SizedBox(height: 24),
                const Text(
                  'iCreate',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildSection('iCreate', 'iCreate', 'icreate'),
                const SizedBox(height: 24),
                const Text(
                  'iRig',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildSection('iRig', 'iRig', 'irig'),
                const SizedBox(height: 24),
                const Text(
                  'Storytime',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildSection('Storytime', 'Storytime', 'storytime'),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
