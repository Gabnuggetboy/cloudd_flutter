class DeviceQueueState {
  // The content currently queued by this user for this device
  final String? queuedContent;

  // The booth name associated with the queued content
  final String? queuedBoothName;

  // The logo URL for the queued content
  final String? queuedLogoUrl;

  // The user's position in the queue (0 = their turn, -1 = not in queue)
  final int queuePosition;

  // Whether it's currently this user's turn
  final bool isUsersTurn;

  // Whether content has been auto-launched for this device
  final bool hasAutoLaunched;

  //Whether auto-launch monitoring is active for this device
  final bool isAutoLaunchActive;

  // Whether a launch is currently in progress (to prevent duplicates)
  final bool isLaunchInProgress;

  // The content currently running on this device (could be another user's)
  final String? runningContent;

  // The icon URL for the running content
  final String? runningContentIconUrl;

  // The client IP that launched the running content
  final String? runningClientIP;

  // The start time of the running content (for playtime tracking)
  final DateTime? runningStartTime;

  // The Firestore document ID for recently played tracking
  final String? runningRecentDocId;

  const DeviceQueueState({
    this.queuedContent,
    this.queuedBoothName,
    this.queuedLogoUrl,
    this.queuePosition = -1,
    this.isUsersTurn = false,
    this.hasAutoLaunched = false,
    this.isAutoLaunchActive = false,
    this.isLaunchInProgress = false,
    this.runningContent,
    this.runningContentIconUrl,
    this.runningClientIP,
    this.runningStartTime,
    this.runningRecentDocId,
  });

  // Creates an empty/initial state
  factory DeviceQueueState.initial() => const DeviceQueueState();

  // Creates a copy with updated fields
  DeviceQueueState copyWith({
    String? queuedContent,
    bool clearQueuedContent = false,
    String? queuedBoothName,
    bool clearQueuedBoothName = false,
    String? queuedLogoUrl,
    bool clearQueuedLogoUrl = false,
    int? queuePosition,
    bool? isUsersTurn,
    bool? hasAutoLaunched,
    bool? isAutoLaunchActive,
    bool? isLaunchInProgress,
    String? runningContent,
    bool clearRunningContent = false,
    String? runningContentIconUrl,
    bool clearRunningContentIconUrl = false,
    String? runningClientIP,
    bool clearRunningClientIP = false,
    DateTime? runningStartTime,
    bool clearRunningStartTime = false,
    String? runningRecentDocId,
    bool clearRunningRecentDocId = false,
  }) {
    return DeviceQueueState(
      queuedContent: clearQueuedContent
          ? null
          : (queuedContent ?? this.queuedContent),
      queuedBoothName: clearQueuedBoothName
          ? null
          : (queuedBoothName ?? this.queuedBoothName),
      queuedLogoUrl: clearQueuedLogoUrl
          ? null
          : (queuedLogoUrl ?? this.queuedLogoUrl),
      queuePosition: queuePosition ?? this.queuePosition,
      isUsersTurn: isUsersTurn ?? this.isUsersTurn,
      hasAutoLaunched: hasAutoLaunched ?? this.hasAutoLaunched,
      isAutoLaunchActive: isAutoLaunchActive ?? this.isAutoLaunchActive,
      isLaunchInProgress: isLaunchInProgress ?? this.isLaunchInProgress,
      runningContent: clearRunningContent
          ? null
          : (runningContent ?? this.runningContent),
      runningContentIconUrl: clearRunningContentIconUrl
          ? null
          : (runningContentIconUrl ?? this.runningContentIconUrl),
      runningClientIP: clearRunningClientIP
          ? null
          : (runningClientIP ?? this.runningClientIP),
      runningStartTime: clearRunningStartTime
          ? null
          : (runningStartTime ?? this.runningStartTime),
      runningRecentDocId: clearRunningRecentDocId
          ? null
          : (runningRecentDocId ?? this.runningRecentDocId),
    );
  }

  // Whether the user has any content queued for this device
  bool get hasQueuedContent => queuedContent != null;

  // Whether there is any content running on this device
  bool get hasRunningContent => runningContent != null;

  @override
  String toString() {
    return 'DeviceQueueState(queuedContent: $queuedContent, queuePosition: $queuePosition, '
        'isUsersTurn: $isUsersTurn, runningContent: $runningContent)';
  }
}
