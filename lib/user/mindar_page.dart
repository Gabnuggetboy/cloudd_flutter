import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:firebase_storage/firebase_storage.dart';

class MindARPage extends StatefulWidget {
  const MindARPage({super.key});

  @override
  State<MindARPage> createState() => _MindARPageState();
}

class _MindARPageState extends State<MindARPage> {
  WebViewController? _controller;
  bool _loading = true;

  HttpServer? _server;

  // In-memory cache for bytes served by local server
  final Map<String, Uint8List> _byteCache = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _init() async {
    // 1) Camera permission
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _loading = true);

    // Download Firebase Storage files into memory, Webview now loads fromm localhost
    await _preloadFirebaseFiles();

    // 3) Start local server that serves index.html + the downloaded files
    await _startLocalServer();

    final localUrl = 'http://127.0.0.1:${_server!.port}/index.html';

    // 4) WebView setup
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => debugPrint("AR: page started"),
          onPageFinished: (_) {
            debugPrint("AR: page finished");
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) =>
              debugPrint("AR web error: ${e.description}"),
        ),
      );

    // MindAR WebView fixes (Android)
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      // Spoof Chrome UA (MindAR often blocks WebView otherwise)
      await controller.setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36',
      );

      platform.setOnPlatformPermissionRequest(
        (request) async => request.grant(),
      );

      await platform.setMediaPlaybackRequiresUserGesture(false);

      AndroidWebViewController.enableDebugging(true);
    }

    if (!mounted) return;
    setState(() => _controller = controller);

    // 5) Load from local server
    await controller.loadRequest(Uri.parse(localUrl));

    // Safety: hide spinner if MindAR continues init in background
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  /// Downloads the files you need from Firebase Storage into memory.
  Future<void> _preloadFirebaseFiles() async {
    final storage = FirebaseStorage.instance;

    // These paths must match what you uploaded: /ar/img_1.png etc.
    final refs = <String, Reference>{
      '/targets_new.mind': storage.ref('ar/targets_new.mind'),
      '/img_1.png': storage.ref('ar/img_1.png'),
      '/img_2.png': storage.ref('ar/img_2.png'),
      '/img_3.png': storage.ref('ar/img_3.png'),
      '/img_4.png': storage.ref('ar/img_4.png'),
    };

    // Download in parallel
    final futures = refs.entries.map((e) async {
      final path = e.key;
      final ref = e.value;

      final bytes = await ref.getData(20 * 1024 * 1024); // 20MB
      if (bytes == null) {
        throw Exception('Failed to download $path from Firebase Storage');
      }
      _byteCache[path] = bytes;
    });

    await Future.wait(futures);
  }

  Future<void> _startLocalServer() async {
    // Shelf handler
    // ignore: prefer_function_declarations_over_variables
    final handler = (Request req) async {
      final path = '/${req.url.path}';
      final normalized = (path == '/' || path == '/index.html')
          ? '/index.html'
          : path;

      // Serve index.html (generated)
      if (normalized == '/index.html') {
        final html = _buildIndexHtml();
        return Response.ok(
          html,
          headers: _headersFor('index.html'),
        );
      }

      // Serve bytes for known files
      final bytes = _byteCache[normalized];
      if (bytes == null) {
        return Response.notFound('Not found: $normalized');
      }

      // Pick content type based on extension
      String fileName = normalized.split('/').last;
      return Response.ok(
        bytes,
        headers: _headersFor(fileName),
      );
    };

    _server = await shelf_io.serve(handler, '127.0.0.1', 0);
    debugPrint('Local AR server running on port ${_server!.port}');
  }

  Map<String, String> _headersFor(String fileName) {
    String contentType = 'application/octet-stream';
    if (fileName.endsWith('.html')) contentType = 'text/html; charset=utf-8';
    if (fileName.endsWith('.js')) contentType = 'application/javascript; charset=utf-8';
    if (fileName.endsWith('.png')) contentType = 'image/png';
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) contentType = 'image/jpeg';
    if (fileName.endsWith('.mind')) contentType = 'application/octet-stream';

    return {
      'content-type': contentType,

      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, OPTIONS',
      'access-control-allow-headers': '*',
      'cache-control': 'no-store',
    };
  }

  String _buildIndexHtml() {
    return '''
      <!doctype html>
      <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />

          <style>
            html, body {
              margin: 0;
              height: 100%;
              overflow: hidden;
              background: transparent;
            }
            a-scene {
              background: transparent !important;
            }
          </style>

          <script src="https://aframe.io/releases/1.5.0/aframe.min.js"></script>
          <script src="https://cdn.jsdelivr.net/npm/mind-ar@1.2.5/dist/mindar-image-aframe.prod.js"></script>
        </head>

        <body>
          <a-scene
            mindar-image="imageTargetSrc: /targets_new.mind; autoStart: true; uiScanning: false;"
            vr-mode-ui="enabled: false"
            device-orientation-permission-ui="enabled: false"
            renderer="colorManagement: true; alpha: true; antialias: true; precision: high;"
            embedded
          >
            <a-assets timeout="10000">
              <img id="img1" crossorigin="anonymous" src="/img_1.png" />
              <img id="img2" crossorigin="anonymous" src="/img_2.png" />
              <img id="img3" crossorigin="anonymous" src="/img_3.png" />
              <img id="img4" crossorigin="anonymous" src="/img_4.png" />
            </a-assets>

            <a-camera position="0 0 0" look-controls="enabled:false"></a-camera>

            <a-entity mindar-image-target="targetIndex: 0">
              <a-plane src="#img1" width="1" height="0.6"
                material="transparent:true; opacity:1"></a-plane>
            </a-entity>

            <a-entity mindar-image-target="targetIndex: 1">
              <a-plane src="#img2" width="1" height="0.6"
                material="transparent:true; opacity:1"></a-plane>
            </a-entity>

            <a-entity mindar-image-target="targetIndex: 2">
              <a-plane src="#img3" width="1" height="0.6"
                material="transparent:true; opacity:1"></a-plane>
            </a-entity>

            <a-entity mindar-image-target="targetIndex: 3">
              <a-plane src="#img4" width="1" height="0.6"
                material="transparent:true; opacity:1"></a-plane>
            </a-entity>
          </a-scene>
        </body>
      </html>
      ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
