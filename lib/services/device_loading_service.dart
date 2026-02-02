import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceLoadingService {
  // Cache: device -> (contentName -> full icon URL)
  static final Map<String, Map<String, String>> _contentIconUrlCache = {};
  static final Map<String, DateTime> _contentIconUrlCacheUpdatedAt = {};
  static const Duration _contentIconUrlCacheTtl = Duration(minutes: 5);

  static const String icubeBase = 'http://192.168.0.143:5000';
  static const String irigBase = 'http://192.168.0.126:5000';
  static const String icreateBase = 'http://192.168.0.129:5000';
  static const String storytimeBase = 'http://192.168.0.103:5000';

  static const Duration timeout = Duration(seconds: 10);

  static const Map<String, String> deviceLogos = {
    'iCube':
        'https://firebasestorage.googleapis.com/v0/b/ddapp-c89cb.firebasestorage.app/o/digitaldream_logos%2Ficube_logo.png?alt=media&token=18ccca3e-3923-469e-b2e8-e3a48157cc85',
    'iCreate':
        'https://firebasestorage.googleapis.com/v0/b/ddapp-c89cb.firebasestorage.app/o/digitaldream_logos%2Ficreate_logo.png?alt=media&token=64791cf0-b248-41a5-a8cf-1d28d0098279',
    'iRig':
        'https://firebasestorage.googleapis.com/v0/b/ddapp-c89cb.firebasestorage.app/o/digitaldream_logos%2Firig_logo.png?alt=media&token=2803e0fe-2356-426a-a16b-9aca3d51c546',
    'Storytime':
        'https://firebasestorage.googleapis.com/v0/b/ddapp-c89cb.firebasestorage.app/o/digitaldream_logos%2Fstorytime_logo.png?alt=media&token=044b121e-a765-487d-b4ee-8599e8aea0d0',
  };

  static Future<DeviceContentResult> _fetchDeviceContent(
    String baseUrl,
    String deviceName,
  ) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/contents'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        final list = json.decode(res.body) as List<dynamic>;
        return DeviceContentResult(contents: list, error: null);
      } else {
        return DeviceContentResult(
          contents: [],
          error: 'Failed to load $deviceName contents: ${res.statusCode}',
        );
      }
    } catch (e) {
      return DeviceContentResult(contents: [], error: '$deviceName: $e');
    }
  }

  static Future<DeviceContentResult> fetchICubeContents() =>
      _fetchDeviceContent(icubeBase, 'iCube');

  static Future<DeviceContentResult> fetchIRigContents() =>
      _fetchDeviceContent(irigBase, 'iRig');

  static Future<DeviceContentResult> fetchICreateContents() =>
      _fetchDeviceContent(icreateBase, 'iCreate');

  static Future<DeviceContentResult> fetchStorytimeContents() =>
      _fetchDeviceContent(storytimeBase, 'Storytime');

  /// Fetch contents for a given device.
  static Future<DeviceContentResult> fetchContentsForDevice(String device) {
    switch (device) {
      case 'iCube':
        return fetchICubeContents();
      case 'iRig':
        return fetchIRigContents();
      case 'iCreate':
        return fetchICreateContents();
      case 'Storytime':
        return fetchStorytimeContents();
      default:
        return Future.value(
          DeviceContentResult(
            contents: const [],
            error: 'Unknown device: $device',
          ),
        );
    }
  }

  /// Resolve a content icon URL by content name.
  ///
  /// This is a best-effort helper for UIs that only have the running content name
  /// (e.g. when the device was launched by another client).
  ///
  /// Uses a small in-memory TTL cache to avoid re-fetching `/contents` repeatedly.
  static Future<String?> resolveContentIconUrl(
    String device,
    String contentName,
  ) async {
    final now = DateTime.now();
    final lastUpdated = _contentIconUrlCacheUpdatedAt[device];

    final cacheIsFresh =
        lastUpdated != null &&
        now.difference(lastUpdated) < _contentIconUrlCacheTtl;

    if (cacheIsFresh) {
      final deviceCache = _contentIconUrlCache[device];
      final cached = deviceCache?[contentName];
      if (cached != null) return cached;
    }

    final contentsResult = await fetchContentsForDevice(device);
    if (contentsResult.error != null) return null;

    final Map<String, String> iconMap = {};
    for (final item in contentsResult.contents) {
      if (item is Map) {
        final name = item['name'];
        final iconPath = item['icon_url'];
        if (name is String && iconPath is String) {
          iconMap[name] = getContentIconUrl(device, iconPath);
        }
      }
    }

    _contentIconUrlCache[device] = iconMap;
    _contentIconUrlCacheUpdatedAt[device] = now;

    return iconMap[contentName];
  }

  // this fetchAllDeviceContents is not used in explore_experience_page.dart
  // because although it will reduce lines of code, it sadly makes loading the page slow...
  //But fetchAllDeviceContents is still used in home_page to load recently played content
  static Future<Map<String, DeviceContentResult>>
  fetchAllDeviceContents() async {
    final results = await Future.wait([
      fetchICubeContents(),
      fetchIRigContents(),
      fetchICreateContents(),
      fetchStorytimeContents(),
    ]);

    return {
      'iCube': results[0],
      'iRig': results[1],
      'iCreate': results[2],
      'Storytime': results[3],
    };
  }

  static String getBaseUrl(String device) {
    switch (device) {
      case 'iCube':
        return icubeBase;
      case 'iRig':
        return irigBase;
      case 'iCreate':
        return icreateBase;
      case 'Storytime':
        return storytimeBase;
      default:
        return '';
    }
  }

  static String getContentIconUrl(String device, String iconPath) {
    return '${getBaseUrl(device)}$iconPath';
  }

  static Future<DeviceLaunchResult> launchContent(
    String device,
    String contentName,
  ) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return DeviceLaunchResult(
        success: false,
        message: 'Unknown device: $device',
      );
    }

    try {
      final res = await http
          .get(Uri.parse('$base/launch/$contentName'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return DeviceLaunchResult(
          success: true,
          message: 'Launching ${data['content']}',
          data: data,
        );
      } else if (res.statusCode == 409) {
        final data = json.decode(res.body);
        return DeviceLaunchResult(
          success: false,
          message: 'Already running: ${data['content']}',
        );
      } else {
        return DeviceLaunchResult(
          success: false,
          message: 'Failed to launch content',
        );
      }
    } catch (e) {
      return DeviceLaunchResult(success: false, message: 'Error: $e');
    }
  }

  static Future<DeviceStopResult> stopContent(
    String device,
    String contentName,
  ) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return DeviceStopResult(
        success: false,
        message: 'Unknown device: $device',
      );
    }

    try {
      final res = await http
          .get(Uri.parse('$base/close/$contentName'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final isSuccess =
            data['status'] == 'success' ||
            data['status'] == null ||
            (data['message'] == null && data['status'] != 'error');

        if (isSuccess) {
          final exeName = data['closed_exe'] ?? data['content'] ?? contentName;
          return DeviceStopResult(
            success: true,
            message: 'Stopped $exeName',
            data: data,
          );
        } else {
          return DeviceStopResult(
            success: false,
            message: data['message'] ?? 'Unknown error',
          );
        }
      } else {
        return DeviceStopResult(
          success: false,
          message: 'Failed to stop content',
        );
      }
    } catch (e) {
      return DeviceStopResult(success: false, message: 'Error: $e');
    }
  }

  static Future<DeviceClientIPResult> getClientIP(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return DeviceClientIPResult(
        clientIP: null,
        runningContent: null,
        status: 'error',
        error: 'Unknown device',
      );
    }

    try {
      final res = await http.get(Uri.parse('$base/client_ip')).timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return DeviceClientIPResult(
          clientIP: data['client_ip'] as String?,
          runningContent: null,
          status: data['status'] as String? ?? 'ok',
          error: null,
        );
      } else {
        return DeviceClientIPResult(
          clientIP: null,
          runningContent: null,
          status: 'error',
          error: 'Failed to get client IP',
        );
      }
    } catch (e) {
      return DeviceClientIPResult(
        clientIP: null,
        runningContent: null,
        status: 'error',
        error: 'Error: $e',
      );
    }
  }

  static Future<DeviceClientIPResult> checkLaunchedClientIP(
    String device,
  ) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return DeviceClientIPResult(
        clientIP: null,
        runningContent: null,
        status: 'error',
        error: 'Unknown device',
      );
    }

    try {
      final res = await http
          .get(Uri.parse('$base/launched_client_device_ip'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return DeviceClientIPResult(
          clientIP: data['client_ip'] as String?,
          runningContent: data['running_content'] as String?,
          status: data['status'] as String? ?? 'unknown',
          error: null,
        );
      } else {
        return DeviceClientIPResult(
          clientIP: null,
          runningContent: null,
          status: 'error',
          error: 'Failed to check client IP',
        );
      }
    } catch (e) {
      return DeviceClientIPResult(
        clientIP: null,
        runningContent: null,
        status: 'error',
        error: 'Error: $e',
      );
    }
  }

  static Future<EnqueueResult> enqueueDevice(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return EnqueueResult(success: false, message: 'Unknown device');
    }

    try {
      final res = await http
          .get(Uri.parse('$base/enqueue/$device'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return EnqueueResult(
          success: true,
          message: 'Added to queue',
          queuePosition: data['queue_position'] as int?,
          queueCount: data['queue_count'] as int?,
        );
      } else {
        return EnqueueResult(success: false, message: 'Failed to enqueue');
      }
    } catch (e) {
      return EnqueueResult(success: false, message: 'Error: $e');
    }
  }

  static Future<QueuePositionResult> getQueuePosition(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return QueuePositionResult(
        inQueue: false,
        queuePosition: -1,
        queueCount: 0,
        error: 'Unknown device',
      );
    }

    try {
      final res = await http
          .get(Uri.parse('$base/queue-position/$device'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final inQueue = data['status'] == 'in_queue';
        return QueuePositionResult(
          inQueue: inQueue,
          queuePosition: data['queue_position'] as int? ?? -1,
          queueCount: data['queue_count'] as int? ?? 0,
          error: null,
        );
      } else {
        return QueuePositionResult(
          inQueue: false,
          queuePosition: -1,
          queueCount: 0,
          error: 'Failed to get queue position',
        );
      }
    } catch (e) {
      return QueuePositionResult(
        inQueue: false,
        queuePosition: -1,
        queueCount: 0,
        error: 'Error: $e',
      );
    }
  }

  static Future<QueueInfoResult> getQueueInfo(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return QueueInfoResult(
        device: device,
        queueCount: 0,
        runningContent: null,
        error: 'Unknown device',
      );
    }

    try {
      final res = await http
          .get(Uri.parse('$base/queue-info/$device'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return QueueInfoResult(
          device: device,
          queueCount: data['queue_count'] as int? ?? 0,
          runningContent: data['running_content'] as String?,
          error: null,
        );
      } else {
        return QueueInfoResult(
          device: device,
          queueCount: 0,
          runningContent: null,
          error: 'Failed to get queue info',
        );
      }
    } catch (e) {
      return QueueInfoResult(
        device: device,
        queueCount: 0,
        runningContent: null,
        error: 'Error: $e',
      );
    }
  }

  static Future<DequeueResult> dequeueDevice(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return DequeueResult(success: false, message: 'Unknown device');
    }

    try {
      final res = await http
          .get(Uri.parse('$base/dequeue/$device'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        return DequeueResult(success: true, message: 'Removed from queue');
      } else {
        return DequeueResult(success: false, message: 'Failed to dequeue');
      }
    } catch (e) {
      return DequeueResult(success: false, message: 'Error: $e');
    }
  }

  // Clear all users from a device's queue (manager only)
  static Future<ClearQueueResult> clearQueue(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return ClearQueueResult(success: false, message: 'Unknown device');
    }

    try {
      final res = await http
          .get(Uri.parse('$base/clear-queue'))
          .timeout(timeout);

      if (res.statusCode == 200) {
        return ClearQueueResult(success: true, message: 'Queue cleared');
      } else {
        return ClearQueueResult(
          success: false,
          message: 'Failed to clear queue',
        );
      }
    } catch (e) {
      return ClearQueueResult(success: false, message: 'Error: $e');
    }
  }

  // Force stop any running content on a device by first checking what's running
  // then stopping it (manager only)
  static Future<DeviceStopResult> forceStopContent(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return DeviceStopResult(
        success: false,
        message: 'Unknown device: $device',
      );
    }

    try {
      // First, check what content is running
      final statusResult = await checkLaunchedClientIP(device);

      if (statusResult.status != 'content_running' ||
          statusResult.runningContent == null) {
        // Nothing running, that's fine
        return DeviceStopResult(
          success: true,
          message: 'No content running on $device',
        );
      }

      // Stop the running content
      final stopResult = await stopContent(
        device,
        statusResult.runningContent!,
      );
      return stopResult;
    } catch (e) {
      return DeviceStopResult(success: false, message: 'Error: $e');
    }
  }
}

class DeviceContentResult {
  final List<dynamic> contents;
  final String? error;

  DeviceContentResult({required this.contents, this.error});
}

class DeviceLaunchResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  DeviceLaunchResult({required this.success, required this.message, this.data});
}

class DeviceStopResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  DeviceStopResult({required this.success, required this.message, this.data});
}

class DeviceClientIPResult {
  final String? clientIP;
  final String? runningContent;
  final String status;
  final String? error;

  DeviceClientIPResult({
    required this.clientIP,
    required this.runningContent,
    required this.status,
    this.error,
  });
}

class EnqueueResult {
  final bool success;
  final String message;
  final int? queuePosition;
  final int? queueCount;

  EnqueueResult({
    required this.success,
    required this.message,
    this.queuePosition,
    this.queueCount,
  });
}

class QueuePositionResult {
  final bool inQueue;
  final int queuePosition;
  final int queueCount;
  final String? error;

  QueuePositionResult({
    required this.inQueue,
    required this.queuePosition,
    required this.queueCount,
    this.error,
  });
}

class QueueInfoResult {
  final String device;
  final int queueCount;
  final String? runningContent;
  final String? error;

  QueueInfoResult({
    required this.device,
    required this.queueCount,
    this.runningContent,
    this.error,
  });
}

class DequeueResult {
  final bool success;
  final String message;

  DequeueResult({required this.success, required this.message});
}

class ClearQueueResult {
  final bool success;
  final String message;

  ClearQueueResult({required this.success, required this.message});
}
