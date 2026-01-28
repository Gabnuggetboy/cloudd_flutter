import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:firebase_storage/firebase_storage.dart';

import 'package:cloudd_flutter/models/AR_Assets.dart';

class MindARPage extends StatefulWidget {
  const MindARPage({super.key});

  @override
  State<MindARPage> createState() => _MindARPageState();
}

class _MindARPageState extends State<MindARPage> {
  WebViewController? _controller;
  bool _loading = true;

  HttpServer? _server;

  /// Bytes served by our localhost server
  final Map<String, Uint8List> _byteCache = {};

  /// Number of images found (img_1.png, img_2.png, ...)
  int _imageCount = 0;

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

    if (mounted) setState(() => _loading = true);

    // 2) Fetch URLs using auto-expanding model
    //    (it returns: target + img1..imgN)
    final urls = await ARAssets.fetchArUrls();

    // 3) Download those URLs into memory and map them to localhost paths:
    //    /targets_new.mind, /img_1.png, /img_2.png, ...
    await _preloadFromUrls(urls);

    // 4) Start local server that serves index.html + downloaded bytes
    await _startLocalServer();

    final localUrl = 'http://127.0.0.1:${_server!.port}/index.html';

    // 5) WebView setup
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

      // Grant camera/mic permissions requested by the page
      platform.setOnPlatformPermissionRequest(
        (request) async => request.grant(),
      );

      // Allow autoplay / camera stream without gesture
      await platform.setMediaPlaybackRequiresUserGesture(false);

      // Enable webview debugging (inspect via chrome://inspect)
      AndroidWebViewController.enableDebugging(true);
    }

    if (!mounted) return;
    setState(() => _controller = controller);

    // 6) Load from local server
    await controller.loadRequest(Uri.parse(localUrl));

    // Safety: hide spinner if MindAR continues init in background
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  /// Downloads bytes from the model's URLs and stores them in _byteCache
  /// under the localhost paths that the HTML expects.
  Future<void> _preloadFromUrls(Map<String, String> urls) async {
    _byteCache.clear();

    final targetUrl = urls['target'];
    if (targetUrl == null || targetUrl.isEmpty) {
      throw Exception("ARAssets.fetchArUrls() did not return 'target'");
    }

    // Download mind file bytes
    _byteCache['/targets_new.mind'] = await _downloadUrlBytes(
      targetUrl,
      maxBytes: 50 * 1024 * 1024, // 50MB
    );

    // Collect model1..modelN keys in numeric order
    final modelEntries = urls.entries
        .where((e) => RegExp(r'^model\d+$').hasMatch(e.key))
        .toList()
      ..sort((a, b) {
        int n(String k) => int.parse(k.replaceAll('model', ''));
        return n(a.key).compareTo(n(b.key));
      });

    _imageCount = modelEntries.length;

    // Download each model and store as /model_#.glb
    await Future.wait(modelEntries.map((e) async {
      final idx = int.parse(e.key.replaceAll('model', '')); // 1-based
      final localPath = '/model_$idx.glb';

      _byteCache[localPath] = await _downloadUrlBytes(
        e.value,
        maxBytes: 50 * 1024 * 1024, // increase for GLB if needed
      );
    }));
  }

  Future<Uint8List> _downloadUrlBytes(
    String url, {
    required int maxBytes,
  }) async {
    // Use FirebaseStorage to fetch by URL
    final ref = FirebaseStorage.instance.refFromURL(url);
    final data = await ref.getData(maxBytes);
    if (data == null) {
      throw Exception('Failed to download bytes from: $url');
    }
    return data;
  }

  Future<void> _startLocalServer() async {
    // ignore: prefer_function_declarations_over_variables
    final handler = (Request req) async {
      // Normalize path
      final path = req.url.path.isEmpty ? '/index.html' : '/${req.url.path}';
      final normalized = path;

      // Serve index.html
      if (normalized == '/index.html') {
        final html = _buildIndexHtml();
        return Response.ok(
          html,
          headers: _headersFor('index.html'),
        );
      }

      // Serve downloaded bytes
      final bytes = _byteCache[normalized];
      if (bytes == null) {
        return Response.notFound('Not found: $normalized');
      }

      final fileName = normalized.split('/').last;
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

    // I JUST KEPT THESE DATA TYPES FOR TRIAL, CODE IS NOT OPTIMISED FOR THESE
    if (fileName.endsWith('.html')) contentType = 'text/html; charset=utf-8';
    if (fileName.endsWith('.js')) contentType = 'application/javascript; charset=utf-8';
    if (fileName.endsWith('.png')) contentType = 'image/png';
    if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    }

    // MAIN DATA TYPES USED
    if (fileName.endsWith('.mind')) contentType = 'application/octet-stream';
    if (fileName.endsWith('.glb')) {
      contentType = 'model/gltf-binary';
    }

    return {
      'content-type': contentType,
      'access-control-allow-origin': '*',
      'access-control-allow-methods': 'GET, OPTIONS',
      'access-control-allow-headers': '*',
      'cache-control': 'no-store',
    };
  }

  String _buildIndexHtml() {
    // // Build <img> tags + target entities dynamically based on _imageCount
    // final assetsImgs = List.generate(_imageCount, (i) {
    //   final n = i + 1;

    //   // Served the image as /img_n.<ext>
    //   // Check cache keys; default to png.
    //   final ext = _byteCache.containsKey('/img_$n.jpg')
    //       ? 'jpg'
    //       : _byteCache.containsKey('/img_$n.jpeg')
    //           ? 'jpeg'
    //           : 'png';

    //   return '<img id="img$n" crossorigin="anonymous" src="/img_$n.$ext" />';
    // }).join('\n');
    final assetsModels = List.generate(_imageCount, (i) {
      final n = i + 1;
      return '<a-asset-item id="model$n" src="/model_$n.glb"></a-asset-item>';
    }).join('\n');

    final entities = List.generate(_imageCount, (i) {
      final n = i + 1;
      final targetIndex = i;

      final yPos = (n == 3 || n == 4) ? -3.0 : 0.0;

      return '''
      <a-entity mindar-image-target="targetIndex: $targetIndex">
        <a-gltf-model
          src="#model$n"
          position="0 $yPos 0"
          rotation="0 0 0"
          scale="0.5 0.5 0.5">
        </a-gltf-model>
      </a-entity>
      ''';
    }).join('\n');



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
            vr-mode-ui="enabled:false"
            device-orientation-permission-ui="enabled:false"
            renderer="colorManagement:true; alpha:true; antialias:true; precision:high;"
            embedded
          >
            <a-assets timeout="10000">
              $assetsModels
            </a-assets>

            <a-camera position="0 0 0" look-controls="enabled:false"></a-camera>

            $entities
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