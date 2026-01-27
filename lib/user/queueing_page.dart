import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/services/image_caching_service.dart';
import 'package:cloudd_flutter/services/queue_service.dart';

class QueueingPage extends StatefulWidget {
  final String? device;

  const QueueingPage({super.key, this.device});

  @override
  State<QueueingPage> createState() => _QueueingPageState();
}

class _QueueingPageState extends State<QueueingPage> {
  late String selectedDevice;
  bool isLoading = true;
  bool isDeviceOffline = false;

  final List<String> devices = QueueService.devices;

  @override
  void initState() {
    super.initState();

    // Initialize selected device
    if (widget.device != null) {
      selectedDevice = widget.device!;
    } else {
      // Find first device with queued content, or default to first device
      final queueService = QueueService();
      selectedDevice = devices.firstWhere(
        (d) => queueService.getQueuedContent(d) != null,
        orElse: () => devices.first,
      );
    }

    _initializeQueue();
  }

  Future<void> _initializeQueue() async {
    final queueService = QueueService();
    try {
      // Check if device is reachable first
      final infoResult = await DeviceLoadingService.getQueueInfo(
        selectedDevice,
      );

      // Check if the device returned an error (offline)
      if (infoResult.error != null &&
          _isDeviceOfflineError(infoResult.error!)) {
        if (mounted) {
          setState(() {
            isLoading = false;
            isDeviceOffline = true;
          });
        }
        return;
      }

      await queueService.loadQueueInfo(selectedDevice);
      queueService.startPolling(selectedDevice);

      if (mounted) {
        setState(() {
          isLoading = false;
          isDeviceOffline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          isDeviceOffline = _isDeviceOfflineError(e.toString());
        });
      }
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

  @override
  void dispose() {
    QueueService().stopPolling();
    super.dispose();
  }

  void _onDeviceChanged(String? newDevice) {
    if (newDevice != null && newDevice != selectedDevice) {
      final queueService = QueueService();
      queueService.stopPolling();

      setState(() {
        selectedDevice = newDevice;
        isLoading = true;
        isDeviceOffline = false;
      });

      // Check if device is reachable first
      DeviceLoadingService.getQueueInfo(newDevice)
          .then((infoResult) {
            // Check if the device returned an error (offline)
            if (infoResult.error != null &&
                _isDeviceOfflineError(infoResult.error!)) {
              if (mounted) {
                setState(() {
                  isLoading = false;
                  isDeviceOffline = true;
                });
              }
              return;
            }

            queueService.loadQueueInfo(newDevice).then((_) {
              queueService.startPolling(newDevice);
              if (mounted) {
                setState(() {
                  isLoading = false;
                  isDeviceOffline = false;
                });
              }
            });
          })
          .catchError((e) {
            if (mounted) {
              setState(() {
                isLoading = false;
                isDeviceOffline = _isDeviceOfflineError(e.toString());
              });
            }
          });
    }
  }

  Future<void> _stopLaunchedContent() async {
    final queueService = context.read<QueueService>();
    final state = queueService.getDeviceState(selectedDevice);

    final String? contentToStop = state.runningContent ?? state.queuedContent;
    if (contentToStop == null) return;

    final result = await queueService.stopContent(
      selectedDevice,
      contentToStop,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveQueue() async {
    final queueService = context.read<QueueService>();
    final state = queueService.getDeviceState(selectedDevice);

    if (state.queuedContent == null) return;

    final success = await queueService.dequeue(selectedDevice);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from queue'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to leave queue'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          ? ImageCacheService().getCachedImage(
              imageUrl: iconUrl,
              fit: BoxFit.cover,
              errorWidget: Center(
                child: Icon(Icons.vrpano, size: 60, color: Colors.grey[600]),
              ),
            )
          : Center(
              child: Icon(Icons.vrpano, size: 60, color: Colors.grey[600]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueService>(
      builder: (context, queueService, child) {
        final state = queueService.getDeviceState(selectedDevice);
        final currentClientIP = queueService.currentClientIP;

        final bool userHasTurn =
            state.isUsersTurn ||
            (state.runningClientIP != null &&
                state.runningClientIP == currentClientIP);
        final bool userIsInQueue =
            state.queuedContent != null && !state.isUsersTurn;

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
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: ImageCacheService().getCachedImage(
                                    imageUrl: DeviceLoadingService
                                        .deviceLogos[device]!,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.contain,
                                    borderRadius: BorderRadius.circular(6),
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
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // Queued content section only show when NOT user's turn
                  if (state.queuedContent != null && !state.isUsersTurn)
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          color: Colors.grey[300],
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: state.queuedLogoUrl != null
                                            ? ImageCacheService()
                                                  .getCachedImage(
                                                    imageUrl:
                                                        state.queuedLogoUrl!,
                                                    fit: BoxFit.cover,
                                                    errorWidget: Center(
                                                      child: Icon(
                                                        Icons.vrpano,
                                                        size: 24,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
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
                                        state.queuedContent ?? '',
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

                  // Loading or queue content
                  if (isLoading)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (isDeviceOffline)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Device is offline',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!userHasTurn)
                              Text(
                                state.queuedContent != null
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
                            else if (state.queuePosition > 0)
                              Column(
                                children: [
                                  const Text(
                                    'There is',
                                    style: TextStyle(fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    '${state.queuePosition}',
                                    style: const TextStyle(
                                      fontSize: 100,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    state.queuePosition == 1
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
                            if (state.runningContent != null ||
                                (state.isUsersTurn &&
                                    state.queuedContent != null))
                              Column(
                                children: [
                                  if (state.isUsersTurn &&
                                      state.queuedContent != null)
                                    _buildContentArtwork(state.queuedLogoUrl)
                                  else if (state.runningContentIconUrl != null)
                                    _buildContentArtwork(
                                      state.runningContentIconUrl,
                                    )
                                  else
                                    FutureBuilder<String?>(
                                      future:
                                          DeviceLoadingService.resolveContentIconUrl(
                                            selectedDevice,
                                            state.runningContent ?? '',
                                          ),
                                      builder: (context, snapshot) {
                                        return _buildContentArtwork(
                                          snapshot.data,
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 12),
                                  Text(
                                    (state.isUsersTurn &&
                                            state.queuedContent != null)
                                        ? state.queuedContent!
                                        : state.runningContent ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  if (state.runningContent != null &&
                                      (state.isUsersTurn ||
                                          (state.runningClientIP != null &&
                                              state.runningClientIP ==
                                                  currentClientIP)))
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
      },
    );
  }
}
