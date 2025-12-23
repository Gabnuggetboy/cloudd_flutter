import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StoryTimeWebappPage extends StatefulWidget {
  const StoryTimeWebappPage({super.key});

  @override
  State<StoryTimeWebappPage> createState() => _StoryTimeWebappPageState();
}

class _StoryTimeWebappPageState extends State<StoryTimeWebappPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            controller.runJavaScript("""
          (function(){
            try {
              var m = document.querySelector('meta[name=viewport]');
              if(m) {
                m.setAttribute('content', 'width=device-width, initial-scale=0.5, maximum-scale=1.0, user-scalable=yes');
              } else {
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0';
                document.head.appendChild(meta);
              }
              var style = document.createElement('style');
              style.type = 'text/css';
              style.appendChild(document.createTextNode('\n  html, body { max-width: 100% !important; overflow-x: hidden !important; }\n  img, video, iframe { max-width:100% !important; height:auto !important; }\n  body * { box-sizing: border-box !important; }\n'));
              document.head.appendChild(style);
            } catch(e) {
              // ignore
            }
          })();
        """);
          },
        ),
      )
      ..loadRequest(Uri.parse('http://192.168.0.103'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storytime Controller')),
      body: WebViewWidget(controller: controller),
    );
  }
}
