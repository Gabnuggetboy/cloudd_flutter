//THIS PAGE IS FOR TESTING WEBAPP ACCESS ONLY

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebAppAccessPage extends StatefulWidget {
  const WebAppAccessPage({super.key});

  @override
  State<WebAppAccessPage> createState() => _WebAppAccessPageState();
}

class _WebAppAccessPageState extends State<WebAppAccessPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('http://192.168.0.103'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebApp Access')),
      body: WebViewWidget(controller: controller),
    );
  }
}
