import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceLoadingService {
  static const String icubeBase = 'http://192.168.0.143:5000';
  static const String irigBase = 'http://192.168.1.81:5000';
  static const String icreateBase = 'http://192.168.0.129:5000';
  static const String storytimeBase = 'http://192.168.0.103:5000';

  static const Duration timeout = Duration(seconds: 10);

  /// Fetches content from a given device API endpoint
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
        return DeviceContentResult(
          contents: list,
          isLoading: false,
          error: null,
        );
      } else {
        return DeviceContentResult(
          contents: [],
          isLoading: false,
          error: 'Failed to load $deviceName contents: ${res.statusCode}',
        );
      }
    } catch (e) {
      return DeviceContentResult(
        contents: [],
        isLoading: false,
        error: '$deviceName: $e',
      );
    }
  }

  /// Fetches iCube contents
  static Future<DeviceContentResult> fetchICubeContents() async {
    return _fetchDeviceContent(icubeBase, 'iCube');
  }

  /// Fetches iRig contents
  static Future<DeviceContentResult> fetchIRigContents() async {
    return _fetchDeviceContent(irigBase, 'iRig');
  }

  /// Fetches iCreate contents
  static Future<DeviceContentResult> fetchICreateContents() async {
    return _fetchDeviceContent(icreateBase, 'iCreate');
  }

  /// Fetches Storytime contents
  static Future<DeviceContentResult> fetchStorytimeContents() async {
    return _fetchDeviceContent(storytimeBase, 'Storytime');
  }

  /// Fetches all device contents concurrently
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

  /// Gets the base URL for a given device name
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

  /// url for content icon
  static String getContentIconUrl(String device, String iconPath) {
    return '${getBaseUrl(device)}$iconPath';
  }

  /// url for content tag
  static String getContentTagUrl(String device, String tagPath) {
    return '${getBaseUrl(device)}$tagPath';
  }

  /// Launches content on a specific device
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
          message: 'Launching ${data['content']}: ${data['status']}',
          data: data,
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

  /// Stops content on a specific device
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
            message: 'Error: ${data['message'] ?? 'Unknown error'}',
          );
        }
      } else if (res.statusCode == 404) {
        return DeviceStopResult(
          success: false,
          message: 'Build executable not found',
        );
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
}

// Result class for device content fetching
class DeviceContentResult {
  final List<dynamic> contents;
  final bool isLoading;
  final String? error;

  DeviceContentResult({
    required this.contents,
    required this.isLoading,
    required this.error,
  });
}

// Result class for launching content
class DeviceLaunchResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  DeviceLaunchResult({required this.success, required this.message, this.data});
}

// Result class for stopping content
class DeviceStopResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  DeviceStopResult({required this.success, required this.message, this.data});
}
