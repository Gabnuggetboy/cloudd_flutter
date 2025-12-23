// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'web_scraper_service.dart';

// class WebViewScraperService {
//   static const String baseUrl = 'http://192.168.0.143';

//   static Future<List<GameData>> fetchRecommendedGames() async {
//     final completer = Completer<List<GameData>>();

//     return completer.future;
//   }

//   static Future<List<GameData>> scrapeWithWebView(
//     WebViewController controller,
//   ) async {
//     try {
//       // Wait for page to load
//       await Future.delayed(const Duration(seconds: 2));

//       // Click the refresh button using JavaScript
//       await controller.runJavaScript('''
//         (function() {
//           var refreshBtn = document.querySelector('.btn-dark');
//           if (refreshBtn) {
//             refreshBtn.click();
//             return 'clicked';
//           }
//           return 'not found';
//         })();
//       ''');

//       // Wait for content to load after clicking refresh
//       await Future.delayed(const Duration(seconds: 2));

//       // Extract game data using JavaScript
//       final result = await controller.runJavaScriptReturningResult('''
//         (function() {
//           var games = [];
//           var elements = document.querySelectorAll('div.img.d-flex.align-items-center.justify-content-center.rounded');
          
//           elements.forEach(function(el) {
//             var style = el.getAttribute('style');
//             if (style && style.includes('background-image')) {
//               var match = style.match(/url\\(['"]?(.+?)['"]?\\)/);
//               if (match && match[1]) {
//                 var imageUrl = match[1];
//                 // Convert relative to absolute URL
//                 if (imageUrl.startsWith('../')) {
//                   imageUrl = imageUrl.replace('../', '');
//                 }
//                 if (!imageUrl.startsWith('http')) {
//                   imageUrl = window.location.origin + '/' + imageUrl;
//                 }
                
//                 var title = el.parentElement ? el.parentElement.textContent.trim() : 'Game';
//                 games.push({
//                   imageUrl: imageUrl,
//                   title: title
//                 });
//               }
//             }
//           });
          
//           return JSON.stringify(games);
//         })();
//       ''');

//       print('WebView scrape result: $result'); // Debug

//       // Parse the result
//       if (result is String) {
//         try {
//           // Remove any escape characters and parse JSON
//           String jsonString = result;

//           // If the result is wrapped in quotes, remove them
//           if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
//             jsonString = jsonString.substring(1, jsonString.length - 1);
//           }

//           // Unescape the JSON string
//           jsonString = jsonString.replaceAll(r'\"', '"');
//           jsonString = jsonString.replaceAll(r'\\', '\\');

//           final List<dynamic> jsonData = json.decode(jsonString);
//           final List<GameData> games = [];

//           for (var item in jsonData) {
//             if (item is Map<String, dynamic> &&
//                 item.containsKey('imageUrl') &&
//                 item.containsKey('title')) {
//               games.add(
//                 GameData(
//                   imageUrl: item['imageUrl'] as String,
//                   title: (item['title'] as String)
//                       .replaceAll('Play', '')
//                       .trim(),
//                 ),
//               );
//             }
//           }

//           print('Parsed ${games.length} games from WebView'); // Debug
//           return games;
//         } catch (e) {
//           print('Error parsing JSON: $e');
//           return [];
//         }
//       }

//       return [];
//     } catch (e) {
//       print('Error scraping with WebView: $e');
//       return [];
//     }
//   }
// }

// // Widget to handle WebView scraping in the background
// class HiddenWebViewScraper extends StatefulWidget {
//   final Function(List<GameData>) onDataFetched;

//   const HiddenWebViewScraper({super.key, required this.onDataFetched});

//   @override
//   State<HiddenWebViewScraper> createState() => _HiddenWebViewScraperState();
// }

// class _HiddenWebViewScraperState extends State<HiddenWebViewScraper> {
//   late WebViewController controller;
//   bool _hasScraped = false;

//   @override
//   void initState() {
//     super.initState();
//     controller = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageFinished: (String url) async {
//             if (!_hasScraped) {
//               _hasScraped = true;
//               // Scrape after page loads
//               final games = await WebViewScraperService.scrapeWithWebView(
//                 controller,
//               );
//               widget.onDataFetched(games);
//             }
//           },
//         ),
//       )
//       ..loadRequest(Uri.parse(WebViewScraperService.baseUrl));
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Hidden WebView (size 0)
//     return SizedBox(
//       width: 0,
//       height: 0,
//       child: WebViewWidget(controller: controller),
//     );
//   }
// }
