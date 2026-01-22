import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

class MindARPage extends StatefulWidget {
  const MindARPage({super.key});

  @override
  State<MindARPage> createState() => _MindARPageState();
}

class _MindARPageState extends State<MindARPage> {
  WebViewController? _controller;
  bool _loading = true;

  HttpServer? _server;

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
    final cam = await Permission.camera.request();
    if (!cam.isGranted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // 1) Start local server
    final handler = (Request req) async {
      // Map routes to your assets
      final path = req.url.path.isEmpty ? 'index.html' : req.url.path;

      const base = 'assets/ar/';
      final assetPath = '$base$path';

      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();

        // Simple content-type guess
        String contentType = 'application/octet-stream';
        if (path.endsWith('.html')) contentType = 'text/html; charset=utf-8';
        if (path.endsWith('.js')) contentType = 'application/javascript; charset=utf-8';
        if (path.endsWith('.png')) contentType = 'image/png';
        if (path.endsWith('.mind')) contentType = 'application/octet-stream';

        return Response.ok(
          bytes,
          headers: {
            'content-type': contentType,
            // Helpful for MindAR / fetch
            'access-control-allow-origin': '*',
          },
        );
      } catch (_) {
        return Response.notFound('Not found');
      }
    };

    _server = await shelf_io.serve(handler, '127.0.0.1', 0);
    final url = 'http://127.0.0.1:${_server!.port}/index.html';

    // 2) WebView
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => debugPrint("AR: page started"),
          onPageFinished: (_) {
            debugPrint("AR: page finished");
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) => debugPrint("AR web error: ${e.description}"),
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnPlatformPermissionRequest((request) async => request.grant());
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }

    if (!mounted) return;
    setState(() => _controller = controller);

    await controller.loadRequest(Uri.parse(url));
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
