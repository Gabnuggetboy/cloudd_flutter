import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceLoadingService {
  static const String icubeBase = 'http://192.168.0.143:5000';
  static const String irigBase = 'http://192.168.0.126:5000';
  static const String icreateBase = 'http://192.168.0.129:5000';
  static const String storytimeBase = 'http://192.168.0.103:5000';

  static const Duration timeout = Duration(seconds: 10);

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

  // this FETCHALLDEVICECONTENTS is not used in explore_experience_page.dart
  // because although it will reduce number of code, it sadly makes loading the page slow...
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

  static Future<DeviceStatusResult> checkDeviceStatus(String device) async {
    final base = getBaseUrl(device);
    if (base.isEmpty) {
      return DeviceStatusResult(
        hasRunningContent: false,
        runningContents: [],
        error: 'Unknown device',
      );
    }

    try {
      final res = await http.get(Uri.parse('$base/status')).timeout(timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return DeviceStatusResult(
          hasRunningContent: data['any_running'] as bool? ?? false,
          runningContents: List<String>.from(
            data['running_contents'] as List? ?? [],
          ),
          error: null,
        );
      } else {
        return DeviceStatusResult(
          hasRunningContent: false,
          runningContents: [],
          error: 'Status check failed',
        );
      }
    } catch (e) {
      return DeviceStatusResult(
        hasRunningContent: false,
        runningContents: [],
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

class DeviceStatusResult {
  final bool hasRunningContent;
  final List<String> runningContents;
  final String? error;

  DeviceStatusResult({
    required this.hasRunningContent,
    required this.runningContents,
    this.error,
  });
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
