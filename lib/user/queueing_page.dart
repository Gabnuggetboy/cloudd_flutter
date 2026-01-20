import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/services/recently_played_service.dart';

class QueueingPage extends StatefulWidget {
  final String? device;
  final String? contentName;
  final Map<String, String?>? queuedContentMap;
  final Map<String, DateTime?>? runningStartMap;
  final Map<String, String?>? runningRecentDocIdMap;

  const QueueingPage({
    super.key,
    this.device,
    this.contentName,
    this.queuedContentMap,
    this.runningStartMap,
    this.runningRecentDocIdMap,
  });

  @override
  State<QueueingPage> createState() => _QueueingPageState();
}

class _QueueingPageState extends State<QueueingPage> {
  String selectedDevice = 'iCube';
  bool isLoading = true;
  final Map<String, bool> isUsersTurn = {}; // Per-device user's turn tracking
  final Map<String, bool> hasAutoLaunched = {}; // Per-device launch tracking

  // Store per-device content and icons
  final Map<String, String?> runningContent = {};
  final Map<String, String?> runningContentIconUrl = {};
  final Map<String, String?> queuedContent =
      {}; // Device-specific queued content
  final Map<String, int> queuePosition = {}; // Track position per device
  final Map<String, String?> runningClientIP =
      {}; // Track running client IP per device

  // Track playtime for recently played
  final Map<String, DateTime?> runningStart = {};
  final Map<String, String?> runningRecentDocId = {};

  String? _currentClientIP; // This user's client IP (per backend)

  final Map<String, Map<String, String>> _iconCache = {};

  bool _contentJustStopped = false;
  DateTime? _lastContentStopTime;
  static const Duration _stopDebounce = Duration(milliseconds: 1500);

  bool _isContentLaunching = false;
  DateTime? _launchStartTime;
  static const Duration _launchDebounce = Duration(milliseconds: 2000);

  final List<String> devices = ['iCube', 'iRig', 'iCreate', 'Storytime'];

  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    // Initialize maps for all devices
    for (final device in devices) {
      runningContent[device] = null;
      runningContentIconUrl[device] = null;
      queuedContent[device] = null;
      queuePosition[device] = 1;
      hasAutoLaunched[device] = false;
      isUsersTurn[device] = false;
      runningClientIP[device] = null;
    }

    // Handle queued content from either single device or Map
    if (widget.queuedContentMap != null) {
      // Use the Map of queued content (from View queue button)
      for (final entry in widget.queuedContentMap!.entries) {
        if (entry.value != null) {
          queuedContent[entry.key] = entry.value;
          // Select first device with queued content
          if (selectedDevice == 'iCube' && entry.value != null) {
            selectedDevice = entry.key;
          }
        }
      }
    } else if (widget.device != null) {
      // Use passed single device/content (from Add to queue dialog)
      selectedDevice = widget.device!;
      queuedContent[selectedDevice] = widget.contentName;
    }

    // Initialize playtime tracking from passed parameters (for content launched from explore page)
    if (widget.runningStartMap != null) {
      for (final entry in widget.runningStartMap!.entries) {
        if (entry.value != null) {
          runningStart[entry.key] = entry.value;
        }
      }
    }
    if (widget.runningRecentDocIdMap != null) {
      for (final entry in widget.runningRecentDocIdMap!.entries) {
        if (entry.value != null) {
          runningRecentDocId[entry.key] = entry.value;
        }
      }
    }

    _loadQueueInfo();
    // Start smart polling that updates only when queue state changes
    _startSmartPolling();
    // Capture current client IP for the selected device's backend
    _getCurrentClientIP();
  }

  Future<void> _getCurrentClientIP() async {
    try {
      final result = await DeviceLoadingService.getClientIP(selectedDevice);
      if (mounted && result.error == null && result.clientIP != null) {
        setState(() {
          _currentClientIP = result.clientIP;
        });
      }
    } catch (e) {
      debugPrint('Error getting client IP: $e');
    }
  }

  void _startSmartPolling() {
    if (_isPolling) return; // Prevent multiple polling loops
    _isPolling = true;
    _pollQueueUpdates();
  }

  Future<void> _pollQueueUpdates() async {
    while (_isPolling && mounted) {
      try {
        final positionResult = await DeviceLoadingService.getQueuePosition(
          selectedDevice,
        );
        final infoResult = await DeviceLoadingService.getQueueInfo(
          selectedDevice,
        );
        // Also check launched client IP to detect if running content belongs to this user
        final launchedStatus = await DeviceLoadingService.checkLaunchedClientIP(
          selectedDevice,
        );

        if (!mounted || !_isPolling) return;

        // Check if running content has changed (could be stopped from explore page)
        final runningContentChanged =
            runningContent[selectedDevice] != infoResult.runningContent;

        // Check if content was running and is now stopped
        final wasContentRunning = runningContent[selectedDevice] != null;
        final isContentNowStopped =
            wasContentRunning && infoResult.runningContent == null;

        // If content was just stopped, mark it for debouncing
        if (isContentNowStopped && !_contentJustStopped) {
          _contentJustStopped = true;
          _lastContentStopTime = DateTime.now();
        }

        // Check if we're still in the debounce window
        final now = DateTime.now();
        final isInDebounceWindow =
            _contentJustStopped &&
            _lastContentStopTime != null &&
            now.difference(_lastContentStopTime!) < _stopDebounce;

        // Check if content is currently launching (skip position updates during this)
        final isStillLaunching =
            _isContentLaunching &&
            _launchStartTime != null &&
            now.difference(_launchStartTime!) < _launchDebounce;

        // Always update if queue position changed or running content changed
        if ((queuePosition[selectedDevice] ?? 1) !=
                positionResult.queuePosition ||
            runningContentChanged) {
          final newIsUsersTurn =
              positionResult.queuePosition == 0 &&
              queuedContent[selectedDevice] != null;

          // Update running client IP map
          runningClientIP[selectedDevice] = launchedStatus.clientIP;
          final bool isRunningByThisClient =
              (_currentClientIP != null &&
              launchedStatus.clientIP != null &&
              launchedStatus.clientIP == _currentClientIP &&
              launchedStatus.status == 'content_running');

          // Resolve icons for updated content
          String? resolvedRunningIcon;
          if (infoResult.runningContent != null &&
              infoResult.runningContent != runningContent[selectedDevice]) {
            resolvedRunningIcon = await _getContentIconUrl(
              selectedDevice,
              infoResult.runningContent!,
            );
          } else if (infoResult.runningContent == null) {
            resolvedRunningIcon = null;
          } else {
            resolvedRunningIcon = runningContentIconUrl[selectedDevice];
          }

          // Check if user's queued content was running and is now stopped
          final wasUserContentRunning =
              runningContent[selectedDevice] == queuedContent[selectedDevice] &&
              queuedContent[selectedDevice] != null;
          final isUserContentNowStopped =
              wasUserContentRunning && infoResult.runningContent == null;

          // Only update UI if not in debounce window OR if position actually improved
          // This prevents flickering while allowing real position changes to show
          // Also skip updates while content is launching to keep "your turn" UI visible
          final positionImproved =
              positionResult.queuePosition <
              (queuePosition[selectedDevice] ?? 999);

          if ((!isInDebounceWindow && !isStillLaunching) ||
              positionImproved ||
              runningContentChanged) {
            setState(() {
              queuePosition[selectedDevice] = positionResult.queuePosition;
              runningContent[selectedDevice] = infoResult.runningContent;
              runningContentIconUrl[selectedDevice] = resolvedRunningIcon;
              // Recompute per-device turn: true if at position 0 with queued content OR
              // if running content belongs to this client. Allow clearing when not launching.
              if (!_isContentLaunching) {
                isUsersTurn[selectedDevice] =
                    newIsUsersTurn || isRunningByThisClient;
              }
            });
          }

          // If user's queued content was running and is now stopped, clear it
          // BUT: Never clear queuedContent or isUsersTurn if they're "in their turn"
          // They need queuedContent to show the stop button and manage their content
          if (isUserContentNowStopped &&
              !(isUsersTurn[selectedDevice] ?? false)) {
            setState(() {
              queuedContent[selectedDevice] = null;
              hasAutoLaunched[selectedDevice] = false;
              runningContent[selectedDevice] = null;
              runningContentIconUrl[selectedDevice] = null;
            });
          }

          // Auto-launch when it's the user's turn (only if not already launching)
          // The hasAutoLaunched flag prevents duplicate launches during polling
          if (newIsUsersTurn &&
              queuedContent[selectedDevice] != null &&
              !(hasAutoLaunched[selectedDevice] ?? false)) {
            hasAutoLaunched[selectedDevice] = true;
            await _launchContent();
          }
        }

        // Clear the stop flag once we're past the debounce window
        if (_contentJustStopped &&
            _lastContentStopTime != null &&
            now.difference(_lastContentStopTime!) >= _stopDebounce) {
          _contentJustStopped = false;
          _lastContentStopTime = null;
        }

        // Clear the launch flag once we're past the launch debounce
        if (_isContentLaunching &&
            _launchStartTime != null &&
            now.difference(_launchStartTime!) >= _launchDebounce) {
          _isContentLaunching = false;
          _launchStartTime = null;
        }

        // Use faster polling during debounce to catch position changes quickly
        final pollDelay = isInDebounceWindow
            ? const Duration(milliseconds: 300)
            : const Duration(seconds: 1);
        await Future.delayed(pollDelay);
      } catch (e) {
        debugPrint('Error in poll: $e');
        if (mounted && _isPolling) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  @override
  void dispose() {
    _isPolling = false;
    _contentJustStopped = false;
    _lastContentStopTime = null;
    _isContentLaunching = false;
    _launchStartTime = null;
    super.dispose();
  }

  Future<void> _loadQueueInfo() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      final positionResult = await DeviceLoadingService.getQueuePosition(
        selectedDevice,
      );
      final infoResult = await DeviceLoadingService.getQueueInfo(
        selectedDevice,
      );
      // Also check launched client IP to detect if running content belongs to this user
      final launchedStatus = await DeviceLoadingService.checkLaunchedClientIP(
        selectedDevice,
      );

      String? resolvedRunningIcon;
      if (infoResult.runningContent != null) {
        resolvedRunningIcon = await _getContentIconUrl(
          selectedDevice,
          infoResult.runningContent!,
        );
      }

      if (mounted) {
        setState(() {
          queuePosition[selectedDevice] = positionResult.queuePosition;
          runningContent[selectedDevice] = infoResult.runningContent;
          runningContentIconUrl[selectedDevice] = resolvedRunningIcon;
          runningClientIP[selectedDevice] = launchedStatus.clientIP;
          // Only set isUsersTurn to true if they're at position 0 AND have queued content
          // Never set it to false here - it persists until user manually stops
          final bool isRunningByThisClient =
              (_currentClientIP != null &&
              launchedStatus.clientIP != null &&
              launchedStatus.clientIP == _currentClientIP &&
              launchedStatus.status == 'content_running');
          final bool turnNow =
              (positionResult.queuePosition == 0 &&
                  queuedContent[selectedDevice] != null) ||
              isRunningByThisClient;
          isUsersTurn[selectedDevice] = turnNow;
          // If not in queue anymore, clear any stale queued content for this device
          if (positionResult.queuePosition == -1) {
            queuedContent[selectedDevice] = null;
            hasAutoLaunched[selectedDevice] = false;
          }
          isLoading = false;
        });

        // Auto-launch when it's the user's turn and they have queued content
        // Only launch once to prevent duplicate launches
        if ((isUsersTurn[selectedDevice] ?? false) &&
            queuedContent[selectedDevice] != null &&
            !(hasAutoLaunched[selectedDevice] ?? false)) {
          hasAutoLaunched[selectedDevice] = true;
          // Delay a bit to ensure UI is updated first
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted &&
                (isUsersTurn[selectedDevice] ?? false) &&
                queuedContent[selectedDevice] != null) {
              await _launchContent();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading queue info: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _onDeviceChanged(String? newDevice) {
    if (newDevice != null && newDevice != selectedDevice) {
      // Stop current polling
      _isPolling = false;

      setState(() {
        selectedDevice = newDevice;
        // Don't reset icons - they are cached per device
        // Don't reset hasAutoLaunched - if content is running on this device, keep the state
        isLoading = true;
      });

      // Don't reset debounce states - they might still apply to content running on this device
      // Just load fresh queue info to get the current state
      _loadQueueInfo();
      // Refresh client IP for this device's backend
      _getCurrentClientIP();
      // Restart polling for the new device
      _startSmartPolling();
    }
  }

  Future<String?> _getContentIconUrl(String device, String contentName) async {
    final cacheForDevice = _iconCache[device];
    if (cacheForDevice != null && cacheForDevice.containsKey(contentName)) {
      return cacheForDevice[contentName];
    }

    final contentsResult = await _fetchContentsForDevice(device);
    if (contentsResult.error != null) {
      debugPrint(
        'Failed to load contents for $device: ${contentsResult.error}',
      );
      return null;
    }

    final Map<String, String> iconMap = {
      for (final content in contentsResult.contents)
        if (content['name'] != null && content['icon_url'] != null)
          content['name'] as String: DeviceLoadingService.getContentIconUrl(
            device,
            content['icon_url'] as String,
          ),
    };

    _iconCache[device] = iconMap;
    return iconMap[contentName];
  }

  Future<DeviceContentResult> _fetchContentsForDevice(String device) {
    switch (device) {
      case 'iCube':
        return DeviceLoadingService.fetchICubeContents();
      case 'iRig':
        return DeviceLoadingService.fetchIRigContents();
      case 'iCreate':
        return DeviceLoadingService.fetchICreateContents();
      case 'Storytime':
        return DeviceLoadingService.fetchStorytimeContents();
      default:
        return Future.value(
          DeviceContentResult(contents: const [], error: 'Unknown device'),
        );
    }
  }

  Widget _buildContentArtwork(String? iconUrl) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[300],
      ),
      clipBehavior: Clip.antiAlias,
      child: iconUrl != null
          ? Image.network(
              iconUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(Icons.vrpano, size: 60, color: Colors.grey[600]),
              ),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
            )
          : Center(
              child: Icon(Icons.vrpano, size: 60, color: Colors.grey[600]),
            ),
    );
  }

  Future<void> _launchContent() async {
    if (queuedContent[selectedDevice] == null) return;

    // Prevent duplicate launches by checking if already launching
    if (hasAutoLaunched[selectedDevice] ?? false) {
      debugPrint(
        'Content already launched or launching, skipping duplicate launch',
      );
      return;
    }

    // Mark that content is launching to prevent polling from clearing the UI
    _isContentLaunching = true;
    _launchStartTime = DateTime.now();

    // Pause polling during launch to prevent UI flashing from stale queue data
    final wasPolling = _isPolling;
    _isPolling = false;

    try {
      final result = await DeviceLoadingService.launchContent(
        selectedDevice,
        queuedContent[selectedDevice]!,
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Launching ${queuedContent[selectedDevice]}'),
              backgroundColor: Colors.green,
            ),
          );

          // Add to recently played with logo URL
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null && queuedContent[selectedDevice] != null) {
            try {
              // Get icon URL for the content
              final iconUrl = await _getContentIconUrl(
                selectedDevice,
                queuedContent[selectedDevice]!,
              );

              final docId = await RecentlyPlayedService.addRecentlyPlayed(
                userId: uid,
                device: selectedDevice,
                boothName: queuedContent[selectedDevice]!,
                experienceId: '', // Empty since we don't have it from queue
                experienceName: '', // Empty since we don't have it from queue
                logoUrl: iconUrl,
              );

              // Store start time and doc ID for playtime tracking
              runningStart[selectedDevice] = DateTime.now();
              runningRecentDocId[selectedDevice] = docId;
            } catch (e) {
              debugPrint('RecentlyPlayed error: $e');
            }
          }

          // Backend automatically dequeues the client after successful launch
          // Don't clear queuedContent yet - let the polling cycle naturally
          // update the UI when it detects the dequeue

          // Mark that we've launched but keep queuedContent for now
          // The polling will detect the dequeue and update UI accordingly
        } else {
          // If already running (409), just acknowledge it
          if (result.message.contains('Already running')) {
            debugPrint('Content already running: ${result.message}');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to launch: ${result.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Resume polling after launch completes
      // The polling will naturally handle the dequeue and state updates
      if (wasPolling && mounted) {
        _isPolling = true;
        _pollQueueUpdates();
      }
    }
  }

  Future<void> _stopLaunchedContent() async {
    final String? contentToStop =
        runningContent[selectedDevice] ?? queuedContent[selectedDevice];
    if (contentToStop == null) return;

    try {
      final result = await DeviceLoadingService.stopContent(
        selectedDevice,
        contentToStop,
      );

      if (mounted) {
        // Update playtime before showing snackbar
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final start = runningStart[selectedDevice];
        final docId = runningRecentDocId[selectedDevice];

        if (uid != null && start != null && docId != null) {
          final seconds = DateTime.now().difference(start).inSeconds;
          await RecentlyPlayedService.updatePlaytimeByDocId(
            userId: uid,
            docId: docId,
            seconds: seconds,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          // Dequeue the device to clear server-side queue state
          await DeviceLoadingService.dequeueDevice(selectedDevice);

          // Immediately reset state and reload queue info
          setState(() {
            queuedContent[selectedDevice] = null;
            isUsersTurn[selectedDevice] = false;
            hasAutoLaunched[selectedDevice] = false;
            runningContent[selectedDevice] = null;
            runningContentIconUrl[selectedDevice] = null;
            runningClientIP[selectedDevice] = null;
            runningStart.remove(selectedDevice);
            runningRecentDocId.remove(selectedDevice);
          });
          // Reload queue info to get fresh data from server
          await _loadQueueInfo();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _leaveQueue() async {
    if (queuedContent[selectedDevice] == null) return;

    try {
      // Dequeue from the server
      final result = await DeviceLoadingService.dequeueDevice(selectedDevice);

      if (mounted) {
        if (result.success) {
          setState(() {
            queuedContent[selectedDevice] = null;
            hasAutoLaunched[selectedDevice] = false;
            // _isAutoLaunchActiveByDevice[selectedDevice] = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Removed from queue'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload queue info to get fresh data
          await _loadQueueInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to leave queue: ${result.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool userHasTurn =
        (isUsersTurn[selectedDevice] ?? false) ||
        ((runningClientIP[selectedDevice] ?? '') == (_currentClientIP ?? ''));
    final bool userIsInQueue =
        queuedContent[selectedDevice] != null &&
        !(isUsersTurn[selectedDevice] ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (userIsInQueue)
            TextButton(
              onPressed: _leaveQueue,
              child: const Text(
                'Leave queue',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Column(
            children: [
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
                        final isSelected = selectedDevice == device;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: GestureDetector(
                            onTap: () => _onDeviceChanged(device),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color.fromRGBO(
                                          143,
                                          148,
                                          251,
                                          1,
                                        ),
                                        width: 3,
                                      )
                                    : null,
                                // color: isSelected
                                //     ? Colors.white
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

              // queued content section only show when NOT user's turn
              if (queuedContent[selectedDevice] != null &&
                  !(isUsersTurn[selectedDevice] ?? false))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your queued content:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.grey[300],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: queuedContent[selectedDevice] != null
                                        ? FutureBuilder<String?>(
                                            future: _getContentIconUrl(
                                              selectedDevice,
                                              queuedContent[selectedDevice]!,
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                      ConnectionState.done &&
                                                  snapshot.data != null) {
                                                return Image.network(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Center(
                                                        child: Icon(
                                                          Icons.vrpano,
                                                          size: 24,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                );
                                              } else {
                                                return Center(
                                                  child: Icon(
                                                    Icons.vrpano,
                                                    size: 24,
                                                    color: Colors.grey[600],
                                                  ),
                                                );
                                              }
                                            },
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.vrpano,
                                              size: 24,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    queuedContent[selectedDevice] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // const SizedBox(height: 32);
              // Loading or queue content
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!userHasTurn)
                          Text(
                            queuedContent[selectedDevice] != null
                                ? 'In Queue'
                                : 'You are not in a queue yet',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        if (!userHasTurn) const SizedBox(height: 4),
                        if (userHasTurn)
                          const Text(
                            "It's your turn, have fun!",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                            textAlign: TextAlign.center,
                          )
                        else if ((queuePosition[selectedDevice] ?? 0) > 0)
                          Column(
                            children: [
                              const Text(
                                'There is',
                                style: TextStyle(fontSize: 18),
                                textAlign: TextAlign.center,
                              ),
                              // const SizedBox(height: 12),
                              Text(
                                '${queuePosition[selectedDevice] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 100,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              // const SizedBox(height: 12),
                              Text(
                                (queuePosition[selectedDevice] ?? 0) == 1
                                    ? 'person ahead of you'
                                    : 'people ahead of you',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Currently Playing:',
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (runningContent[selectedDevice] != null ||
                            ((isUsersTurn[selectedDevice] ?? false) &&
                                queuedContent[selectedDevice] != null))
                          Column(
                            children: [
                              if ((isUsersTurn[selectedDevice] ?? false) &&
                                  queuedContent[selectedDevice] != null)
                                FutureBuilder<String?>(
                                  future: _getContentIconUrl(
                                    selectedDevice,
                                    queuedContent[selectedDevice]!,
                                  ),
                                  builder: (context, snapshot) {
                                    return _buildContentArtwork(snapshot.data);
                                  },
                                )
                              else
                                _buildContentArtwork(
                                  runningContentIconUrl[selectedDevice],
                                ),
                              const SizedBox(height: 12),
                              Text(
                                ((isUsersTurn[selectedDevice] ?? false) &&
                                        queuedContent[selectedDevice] != null)
                                    ? queuedContent[selectedDevice]!
                                    : runningContent[selectedDevice] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              if (runningContent[selectedDevice] != null &&
                                  (((isUsersTurn[selectedDevice] ?? false)) ||
                                      ((runningClientIP[selectedDevice] ??
                                              '') ==
                                          (_currentClientIP ?? ''))))
                                ElevatedButton.icon(
                                  onPressed: _stopLaunchedContent,
                                  icon: const Icon(Icons.stop_circle),
                                  label: const Text('Stop Content'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          )
                        else
                          const Text(
                            'Nothing playing',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
