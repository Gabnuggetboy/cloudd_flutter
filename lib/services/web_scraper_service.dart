// import 'package:http/http.dart' as http;
// import 'package:html/parser.dart' as html;
// import 'dart:convert';

// class GameData {
//   final String imageUrl;
//   final String title;

//   GameData({required this.imageUrl, required this.title});
// }

// class WebScraperService {
//   static const String baseUrl = 'http://192.168.0.143';

//   static Future<List<GameData>> fetchRecommendedGames() async {
//     try {
//       // First, try to trigger the refresh endpoint if it exists
//       // This simulates clicking the refresh button
//       try {
//         await http.post(
//           Uri.parse('$baseUrl/refresh'),
//           headers: {'Content-Type': 'application/json'},
//         );
//       } catch (e) {
//         // Refresh endpoint might not exist, continue anyway
//       }

//       // Add a small delay to let the server process
//       await Future.delayed(const Duration(milliseconds: 500));

//       final response = await http.get(Uri.parse(baseUrl));

//       if (response.statusCode != 200) {
//         throw Exception('Failed to load page: ${response.statusCode}');
//       }

//       final document = html.parse(response.body);
//       final List<GameData> games = [];

//       // Find all divs with class "img d-flex align-items-center justify-content-center rounded"
//       final gameElements = document.querySelectorAll(
//         'div.img.d-flex.align-items-center.justify-content-center.rounded',
//       );

//       print('Found ${gameElements.length} game elements'); // Debug

//       for (var element in gameElements) {
//         final style = element.attributes['style'];
//         if (style != null && style.contains('background-image')) {
//           // Extract URL from style="background-image: url('../Uploads/...')"
//           final urlMatch = RegExp(
//             r'''url\(['"]?(.+?)['"]?\)''',
//           ).firstMatch(style);
//           if (urlMatch != null) {
//             var imageUrl = urlMatch.group(1)!;

//             // Convert relative URL to absolute
//             if (imageUrl.startsWith('../')) {
//               imageUrl = imageUrl.replaceFirst('../', '');
//             }
//             if (!imageUrl.startsWith('http')) {
//               imageUrl = '$baseUrl/$imageUrl';
//             }

//             // Try to extract title from nearby elements (adjust as needed)
//             final title = element.parent?.text.trim() ?? 'Game';

//             print('Found game: $title - $imageUrl'); // Debug
//             games.add(GameData(imageUrl: imageUrl, title: title));
//           }
//         }
//       }

//       print('Total games found: ${games.length}'); // Debug
//       return games;
//     } catch (e) {
//       print('Error fetching games: $e'); // Debug
//       return [];
//     }
//   }
// }
