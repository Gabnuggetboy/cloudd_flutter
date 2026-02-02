import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/models/queue_state.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/services/recently_played_service.dart';

// Centralized service for managing device queues across the app.
// Uses ChangeNotifier to notify listeners of state changes.
class QueueService extends ChangeNotifier {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  // List of DD Devices
  static const List<String> devices = ['iCube', 'iRig', 'iCreate', 'Storytime'];

  // Per-device queue states
  final Map<String, DeviceQueueState> _deviceStates = {};

  // This is current user's client IP
  String? _currentClientIP;

  // Polling control
  bool _isPolling = false;
  String? _pollingDevice;

  // Debounce tracking
  bool _contentJustStopped = false;
  DateTime? _lastContentStopTime;
  static const Duration _stopDebounce = Duration(milliseconds: 1500);

  bool _isContentLaunching = false;
  DateTime? _launchStartTime;
  static const Duration _launchDebounce = Duration(milliseconds: 2000);

  // Last state update times for debouncing UI updates
  final Map<String, DateTime> _lastStateUpdateTime = {};
  static const Duration _pollDebounce = Duration(milliseconds: 1000);

  //GETTERS
  // Get the current client IP
  String? get currentClientIP => _currentClientIP;

  // Get state for a specific device
  DeviceQueueState getDeviceState(String device) {
    return _deviceStates[device] ?? DeviceQueueState.initial();
  }

  // Get queued content for a device
  String? getQueuedContent(String device) =>
      getDeviceState(device).queuedContent;

  // INITIALIZATIONS

  // Initialize the service and fetch current client IP
  Future<void> initialize() async {
    // Initialize states for all devices
    for (final device in devices) {
      _deviceStates[device] = DeviceQueueState.initial();
    }
    await _fetchCurrentClientIP();
  }

  /// Fetch the current client IP from the backend
  Future<void> _fetchCurrentClientIP() async {
    try {
      final result = await DeviceLoadingService.getClientIP('iCube');
      if (result.error == null && result.clientIP != null) {
        _currentClientIP = result.clientIP;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('QueueService: Error getting client IP: $e');
    }
  }

  /// Refresh client IP (call when switching devices or after launch)
  Future<void> refreshClientIP() async {
    await _fetchCurrentClientIP();
  }

  //STATE UPDATES

  // Update state for a specific device
  void _updateDeviceState(String device, DeviceQueueState newState) {
    _deviceStates[device] = newState;
    _lastStateUpdateTime[device] = DateTime.now();
    notifyListeners();
  }

  DeviceQueueState _clearQueuedState(DeviceQueueState state) {
    return state.copyWith(
      clearQueuedContent: true,
      clearQueuedBoothName: true,
      clearQueuedLogoUrl: true,
      clearQueuedExperienceId: true,
      clearQueuedExperienceName: true,
    );
  }

  DeviceQueueState _clearRunningState(DeviceQueueState state) {
    return state.copyWith(
      clearRunningContent: true,
      clearRunningContentIconUrl: true,
      clearRunningClientIP: true,
      clearRunningStartTime: true,
      clearRunningRecentDocId: true,
    );
  }

  DeviceQueueState _clearRunningContentState(DeviceQueueState state) {
    return state.copyWith(
      clearRunningContent: true,
      clearRunningContentIconUrl: true,
    );
  }

  bool _isUsersTurn({
    required int queuePosition,
    required String? queuedContent,
    required bool isRunningByThisClient,
  }) {
    return (queuePosition == 0 && queuedContent != null) || isRunningByThisClient;
  }

  //QUEUE OPERATIONS

  // Enqueue the user for a device with specific content
  Future<bool> enqueue(
    String device,
    String contentName, {
    String? boothName,
    String? logoUrl,
    String? experienceId,
    String? experienceName,
  }) async {
    try {
      final result = await DeviceLoadingService.enqueueDevice(device);
      if (result.success) {
        final currentState = getDeviceState(device);
        _updateDeviceState(
          device,
          currentState.copyWith(
            queuedContent: contentName,
            queuedBoothName: boothName ?? contentName,
            queuedLogoUrl: logoUrl,
            queuedExperienceId: experienceId,
            queuedExperienceName: experienceName,
            isAutoLaunchActive: true,
            hasAutoLaunched: false,
          ),
        );
        // Start monitoring for when it's the user's turn
        _startAutoLaunchMonitor(device);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('QueueService: Error enqueuing: $e');
      return false;
    }
  }

  //Dequeue/leave the queue for a device
  Future<bool> dequeue(String device) async {
    try {
      final result = await DeviceLoadingService.dequeueDevice(device);
      if (result.success) {
        final currentState = getDeviceState(device);
        _updateDeviceState(
          device,
          _clearQueuedState(currentState).copyWith(
            isAutoLaunchActive: false,
            hasAutoLaunched: false,
            queuePosition: -1,
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('QueueService: Error dequeuing: $e');
      return false;
    }
  }

  // LAUNCHING/STOPPING CONTENT

  /// Launch content on a device
  /// Returns a LaunchResult with success status and message
  Future<LaunchResult> launchContent(
    String device,
    String contentName, {
    String? boothName,
    String? logoUrl,
    String? experienceId,
    String? experienceName,
  }) async {
    final currentState = getDeviceState(device);

    // To prevent duplicate launches
    if (currentState.isLaunchInProgress) {
      debugPrint('QueueService: Launch already in progress for $device');
      return LaunchResult(
        success: false,
        message: 'Launch already in progress',
      );
    }

    if (_currentClientIP == null) {
      try {
        await DeviceLoadingService.checkLaunchedClientIP(device);
      } catch (e) {
        debugPrint('QueueService: Error establishing device IP: $e');
      }
    }

    // Check if device is in use by another client
    final clientIPResult = await DeviceLoadingService.checkLaunchedClientIP(
      device,
    );

    if (clientIPResult.status == 'content_running' &&
        clientIPResult.clientIP != null) {
      // If we dk our IP or it doesn't match, means device is in use by someone else
      if (_currentClientIP == null ||
          clientIPResult.clientIP != _currentClientIP) {
        return LaunchResult(
          success: false,
          message: 'Device in use by another user',
          deviceInUse: true,
        );
      }

      // Our own content is running
      //stop it first if want to run different content
      if (clientIPResult.runningContent != null &&
          clientIPResult.runningContent != contentName) {
        await stopContent(device, clientIPResult.runningContent!);
      }
    }

    // Also handle local tracking of running content
    if (currentState.runningContent != null &&
        currentState.runningContent != contentName) {
      await stopContent(device, currentState.runningContent!);
    }

    // Set launch lock
    _updateDeviceState(
      device,
      currentState.copyWith(isLaunchInProgress: true, hasAutoLaunched: true),
    );

    _isContentLaunching = true;
    _launchStartTime = DateTime.now();

    try {
      final result = await DeviceLoadingService.launchContent(
        device,
        contentName,
      );

      if (result.success) {
        // Refresh client IP after successful launch
        await refreshClientIP();

        // Icon URL for recently played
        final iconUrl = logoUrl;

        // Add to recently played
        String? docId;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          try {
            docId = await RecentlyPlayedService.addRecentlyPlayed(
              userId: uid,
              device: device,
              boothName: boothName ?? contentName,
              experienceId: experienceId ?? '',
              experienceName: experienceName ?? '',
              logoUrl: iconUrl,
            );
          } catch (e) {
            debugPrint('QueueService: RecentlyPlayed error: $e');
          }
        }

        // Update state with running content
        // Set runningClientIP to current user's IP for immediate UI update
        _updateDeviceState(
          device,
          getDeviceState(device).copyWith(
            runningContent: contentName,
            runningContentIconUrl: iconUrl,
            runningClientIP: _currentClientIP,
            runningStartTime: DateTime.now(),
            runningRecentDocId: docId,
            isLaunchInProgress: false,
            isUsersTurn: true,
          ),
        );

        return LaunchResult(success: true, message: result.message);
      } else {
        // Release lock on failure
        _updateDeviceState(
          device,
          getDeviceState(device).copyWith(isLaunchInProgress: false),
        );
        return LaunchResult(success: false, message: result.message);
      }
    } catch (e) {
      // Release lock on error
      _updateDeviceState(
        device,
        getDeviceState(device).copyWith(isLaunchInProgress: false),
      );
      return LaunchResult(success: false, message: 'Error: $e');
    } finally {
      _isContentLaunching = false;
      _launchStartTime = null;
    }
  }

  /// Stop running content on a device
  Future<StopResult> stopContent(String device, String contentName) async {
    try {
      final result = await DeviceLoadingService.stopContent(
        device,
        contentName,
      );

      // Update playtime before clearing state
      final currentState = getDeviceState(device);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final start = currentState.runningStartTime;
      final docId = currentState.runningRecentDocId;

      if (uid != null && start != null && docId != null) {
        final seconds = DateTime.now().difference(start).inSeconds;
        await RecentlyPlayedService.updatePlaytimeByDocId(
          userId: uid,
          docId: docId,
          seconds: seconds,
        );
      }

      if (result.success) {
        // Also dequeue to clear server-side state
        await DeviceLoadingService.dequeueDevice(device);

        // Mark content as just stopped for debouncing
        _contentJustStopped = true;
        _lastContentStopTime = DateTime.now();

        // Clear running state
        _updateDeviceState(
          device,
          _clearQueuedState(_clearRunningState(currentState)).copyWith(
            isUsersTurn: false,
            hasAutoLaunched: false,
            isAutoLaunchActive: false,
            isLaunchInProgress: false,
            queuePosition: -1,
          ),
        );
      }

      return StopResult(success: result.success, message: result.message);
    } catch (e) {
      return StopResult(success: false, message: 'Error: $e');
    }
  }

  // AUTO LAUNCH MONITORING

  // Start monitoring for when it's the user's turn to auto-launch
  void _startAutoLaunchMonitor(String device) {
    _checkAndLaunchWhenTurn(device);
  }

  // Check queue position and launch when it's user's turn
  void _checkAndLaunchWhenTurn(String device) {
    final state = getDeviceState(device);
    if (!state.isAutoLaunchActive || state.queuedContent == null) {
      return;
    }

    if (state.isLaunchInProgress) {
      debugPrint(
        'QueueService: Launch already in progress for $device, skipping',
      );
      return;
    }

    Future.delayed(const Duration(seconds: 2), () async {
      final currentState = getDeviceState(device);
      if (!currentState.isAutoLaunchActive ||
          currentState.queuedContent == null) {
        return;
      }

      if (currentState.isLaunchInProgress) {
        debugPrint(
          'QueueService: Launch already in progress for $device, skipping delayed check',
        );
        return;
      }

      try {
        final positionResult = await DeviceLoadingService.getQueuePosition(
          device,
        );

        final latestState = getDeviceState(device);
        if (!latestState.isAutoLaunchActive ||
            latestState.queuedContent == null) {
          return;
        }

        if (positionResult.queuePosition == 0) {
          // User's turn! Auto-launch the content
          _updateDeviceState(
            device,
            latestState.copyWith(isAutoLaunchActive: false),
          );

          await launchContent(
            device,
            latestState.queuedContent!,
            boothName: latestState.queuedBoothName,
            logoUrl: latestState.queuedLogoUrl,
            experienceId: latestState.queuedExperienceId,
            experienceName: latestState.queuedExperienceName,
          );
        } else {
          // Not yet user's turn, check again
          _checkAndLaunchWhenTurn(device);
        }
      } catch (e) {
        debugPrint('QueueService: Error checking queue position: $e');
        final latestState = getDeviceState(device);
        if (latestState.isAutoLaunchActive) {
          _checkAndLaunchWhenTurn(device);
        }
      }
    });
  }

  // POLLING

  /// Start polling for queue updates for a specific device
  void startPolling(String device) {
    if (_isPolling && _pollingDevice == device) return;

    _isPolling = true;
    _pollingDevice = device;
    _pollQueueUpdates(device);
  }

  /// Stop polling
  void stopPolling() {
    _isPolling = false;
    _pollingDevice = null;
  }

  /// Poll for queue updates
  Future<void> _pollQueueUpdates(String device) async {
    while (_isPolling && _pollingDevice == device) {
      try {
        final positionResult = await DeviceLoadingService.getQueuePosition(
          device,
        );
        final infoResult = await DeviceLoadingService.getQueueInfo(device);
        final launchedStatus = await DeviceLoadingService.checkLaunchedClientIP(
          device,
        );

        if (!_isPolling || _pollingDevice != device) return;

        final currentState = getDeviceState(device);
        final now = DateTime.now();

        // Check debounce windows
        final isInStopDebounce =
            _contentJustStopped &&
            _lastContentStopTime != null &&
            now.difference(_lastContentStopTime!) < _stopDebounce;

        final isStillLaunching =
            _isContentLaunching &&
            _launchStartTime != null &&
            now.difference(_launchStartTime!) < _launchDebounce;

        // Determine if running content is from this client
        final bool isRunningByThisClient =
            _currentClientIP != null &&
            launchedStatus.clientIP != null &&
            launchedStatus.clientIP == _currentClientIP &&
            launchedStatus.status == 'content_running';

        // Resolve icon for running content (best-effort)
        // We only have a reliable icon URL when we launched the content ourselves.
        String? resolvedRunningIcon;
        if (infoResult.runningContent == null) {
          resolvedRunningIcon = null;
        } else if (infoResult.runningContent == currentState.runningContent) {
          resolvedRunningIcon = currentState.runningContentIconUrl;
        } else {
          // Running content changed (possibly launched by someone else). No icon available.
          resolvedRunningIcon = null;
        }

        // Calculate new turn status
        final newIsUsersTurn = _isUsersTurn(
          queuePosition: positionResult.queuePosition,
          queuedContent: currentState.queuedContent,
          isRunningByThisClient: isRunningByThisClient,
        );

        // Check if we should update
        final runningContentChanged =
            currentState.runningContent != infoResult.runningContent;
        final positionImproved =
            positionResult.queuePosition < currentState.queuePosition;

        if ((!isInStopDebounce && !isStillLaunching) ||
            positionImproved ||
            runningContentChanged) {
          // Check if users queued content was running and is now stopped
          final wasUserContentRunning =
              currentState.runningContent == currentState.queuedContent &&
              currentState.queuedContent != null;
          final isUserContentNowStopped =
              wasUserContentRunning && infoResult.runningContent == null;

          DeviceQueueState newState = currentState.copyWith(
            queuePosition: positionResult.queuePosition,
            runningClientIP: launchedStatus.clientIP,
          );

          // Update running content if not launching
          if (!_isContentLaunching) {
            newState = newState.copyWith(isUsersTurn: newIsUsersTurn);

            if (runningContentChanged) {
              if (infoResult.runningContent == null) {
                newState = _clearRunningContentState(newState);
              } else {
                newState = newState.copyWith(
                  runningContent: infoResult.runningContent,
                  runningContentIconUrl: resolvedRunningIcon,
                );
              }
            }
          }

          // If user's queued content was running and is now stopped, clear it
          if (isUserContentNowStopped && !newIsUsersTurn) {
            newState = _clearQueuedState(_clearRunningContentState(newState))
                .copyWith(
              hasAutoLaunched: false,
            );
          }

          // If not in queue anymore, clear stale queued content
          if (positionResult.queuePosition == -1 && !isRunningByThisClient) {
            newState = _clearQueuedState(newState).copyWith(
              hasAutoLaunched: false,
            );
          }

          _updateDeviceState(device, newState);
        }

        // Auto-launch when it's the user's turn
        if (newIsUsersTurn &&
            currentState.queuedContent != null &&
            !currentState.hasAutoLaunched &&
            !currentState.isLaunchInProgress) {
          await launchContent(
            device,
            currentState.queuedContent!,
            boothName: currentState.queuedBoothName,
            logoUrl: currentState.queuedLogoUrl,
            experienceId: currentState.queuedExperienceId,
            experienceName: currentState.queuedExperienceName,
          );
        }

        // Clear debounce flags after window expires
        if (_contentJustStopped &&
            _lastContentStopTime != null &&
            now.difference(_lastContentStopTime!) >= _stopDebounce) {
          _contentJustStopped = false;
          _lastContentStopTime = null;
        }

        // Poll interval
        final pollDelay = isInStopDebounce
            ? const Duration(milliseconds: 300)
            : const Duration(seconds: 1);
        await Future.delayed(pollDelay);
      } catch (e) {
        debugPrint('QueueService: Error in poll: $e');
        if (_isPolling) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  /// Poll running status for all devices (for explore page)
  Future<void> pollAllDevicesRunningStatus() async {
    try {
      await Future.wait(
        devices.map((device) async {
          final status = await DeviceLoadingService.checkLaunchedClientIP(
            device,
          );
          final currentState = getDeviceState(device);

          // Skip if recently updated locally
          final lastUpdate = _lastStateUpdateTime[device];
          if (lastUpdate != null &&
              DateTime.now().difference(lastUpdate) < _pollDebounce) {
            return;
          }

          // Always update runningClientIP and runningContent from server
          // The UI will filter based on client IP to show only user's own content
          final bool hasRunningContent =
              status.status == 'content_running' &&
              status.runningContent != null;

          final contentChanged =
              currentState.runningContent != status.runningContent;
          final clientIPChanged =
              currentState.runningClientIP != status.clientIP;

          if (contentChanged || clientIPChanged) {
            // Best-effort icon: only available when we launched the content ourselves.
            String? iconUrl;
            if (hasRunningContent &&
                status.runningContent == currentState.runningContent) {
              iconUrl = currentState.runningContentIconUrl;
            }

            _updateDeviceState(
              device,
              currentState.copyWith(
                runningContent: hasRunningContent
                    ? status.runningContent
                    : null,
                runningContentIconUrl: hasRunningContent ? iconUrl : null,
                runningClientIP: status.clientIP,
                clearRunningContent: !hasRunningContent,
                clearRunningContentIconUrl: !hasRunningContent,
                clearRunningClientIP: status.clientIP == null,
              ),
            );
          }
        }),
      );
    } catch (e) {
      debugPrint('QueueService: Error polling all devices: $e');
    }
  }

  // QUEUE INFO

  /// Load queue info for a specific device
  Future<void> loadQueueInfo(String device) async {
    try {
      final positionResult = await DeviceLoadingService.getQueuePosition(
        device,
      );
      final infoResult = await DeviceLoadingService.getQueueInfo(device);
      final launchedStatus = await DeviceLoadingService.checkLaunchedClientIP(
        device,
      );

      // Best-effort icon: only available when we launched the content ourselves.
      String? resolvedRunningIcon;
      if (infoResult.runningContent != null &&
          infoResult.runningContent == getDeviceState(device).runningContent) {
        resolvedRunningIcon = getDeviceState(device).runningContentIconUrl;
      }

      final currentState = getDeviceState(device);
      final bool isRunningByThisClient =
          _currentClientIP != null &&
          launchedStatus.clientIP != null &&
          launchedStatus.clientIP == _currentClientIP &&
          launchedStatus.status == 'content_running';

      final bool turnNow = _isUsersTurn(
        queuePosition: positionResult.queuePosition,
        queuedContent: currentState.queuedContent,
        isRunningByThisClient: isRunningByThisClient,
      );

      DeviceQueueState newState = currentState.copyWith(
        queuePosition: positionResult.queuePosition,
        runningContent: infoResult.runningContent,
        runningContentIconUrl: resolvedRunningIcon,
        runningClientIP: launchedStatus.clientIP,
        isUsersTurn: turnNow,
      );

      // Clear stale queued content if not in queue
      if (positionResult.queuePosition == -1 && !isRunningByThisClient) {
        newState = _clearQueuedState(newState).copyWith(
          hasAutoLaunched: false,
        );
      }

      _updateDeviceState(device, newState);

      // Auto-launch if it's user's turn
      if (turnNow &&
          currentState.queuedContent != null &&
          !currentState.hasAutoLaunched &&
          !currentState.isLaunchInProgress) {
        await launchContent(
          device,
          currentState.queuedContent!,
          boothName: currentState.queuedBoothName,
          logoUrl: currentState.queuedLogoUrl,
          experienceId: currentState.queuedExperienceId,
          experienceName: currentState.queuedExperienceName,
        );
      }
    } catch (e) {
      debugPrint('QueueService: Error loading queue info: $e');
    }
  }

  /// Refresh queue state (check positions for all devices and clear stale entries)
  Future<void> refreshQueueState() async {
    for (final device in devices) {
      final currentState = getDeviceState(device);
      if (currentState.queuedContent != null) {
        try {
          final positionResult = await DeviceLoadingService.getQueuePosition(
            device,
          );
          if (positionResult.queuePosition == -1) {
            _updateDeviceState(
              device,
              _clearQueuedState(currentState).copyWith(
                isAutoLaunchActive: false,
              ),
            );
          }
        } catch (e) {
          debugPrint(
            'QueueService: Error checking queue position for $device: $e',
          );
        }
      }
    }
  }

  // CLEANUP

  // Dispose and cleanup
  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  // MANAGER OPERATIONS

  // Force stop all content and clear all queues for an experience's booths
  // This is manager-only operation
  // Note: Offline devices (connection errors/timeouts) are treated as successful
  // since theres nothing to reset on a device that isn't there
  static Future<ForceStopExperienceResult> forceStopExperience(
    List<Map<String, dynamic>> booths,
  ) async {
    final List<String> errors = [];
    final List<String> successes = [];
    final List<String> skipped = [];

    // Get unique devices from booths
    final Set<String> affectedDevices = {};
    for (final booth in booths) {
      final device = booth['device'] as String?;
      if (device != null && devices.contains(device)) {
        affectedDevices.add(device);
      }
    }

    // For each affected device, clear queue and force stop content
    for (final device in affectedDevices) {
      try {
        // First, force stop any running content
        final stopResult = await DeviceLoadingService.forceStopContent(device);
        if (stopResult.success) {
          successes.add('Stopped content on $device');
        } else {
          // Check if it's a connection/timeout error (device offline)
          if (_isDeviceOfflineError(stopResult.message)) {
            skipped.add('$device is offline');
          } else {
            errors.add(
              'Failed to stop content on $device: ${stopResult.message}',
            );
          }
        }

        // Then clear the queue (only if device responded to stop request)
        if (!_isDeviceOfflineError(stopResult.message)) {
          final clearResult = await DeviceLoadingService.clearQueue(device);
          if (clearResult.success) {
            successes.add('Cleared queue for $device');
          } else {
            if (_isDeviceOfflineError(clearResult.message)) {
              skipped.add('$device queue skip - offline');
            } else {
              errors.add(
                'Failed to clear queue for $device: ${clearResult.message}',
              );
            }
          }
        }
      } catch (e) {
        // Connection errors mean the device is offline - not a failure
        final errorStr = e.toString();
        if (_isDeviceOfflineError(errorStr)) {
          skipped.add('$device is offline');
        } else {
          errors.add('Error processing $device: $e');
        }
      }
    }

    return ForceStopExperienceResult(
      success: errors.isEmpty,
      successMessages: successes,
      errorMessages: errors,
      skippedDevices: skipped,
    );
  }

  // Check if an error message indicates the device is offline
  static bool _isDeviceOfflineError(String message) {
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
}

// Result of a force stop experience operation
class ForceStopExperienceResult {
  final bool success;
  final List<String> successMessages;
  final List<String> errorMessages;
  final List<String> skippedDevices;

  ForceStopExperienceResult({
    required this.success,
    required this.successMessages,
    required this.errorMessages,
    this.skippedDevices = const [],
  });
}

// Result of a launch operation
class LaunchResult {
  final bool success;
  final String message;
  final bool deviceInUse;

  LaunchResult({
    required this.success,
    required this.message,
    this.deviceInUse = false,
  });
}

// Result of a stop operation
class StopResult {
  final bool success;
  final String message;

  StopResult({required this.success, required this.message});
}
