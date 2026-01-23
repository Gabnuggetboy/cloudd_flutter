import 'package:firebase_storage/firebase_storage.dart';

class ARAssets {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Fetches the mind target + all images (img_1.png, img_2.png, ...)
  /// automatically from Storage folder: ar/
  static Future<Map<String, String>> fetchArUrls({
    String mindPath = 'ar/targets_new.mind',
    String folderPath = 'ar',
  }) async {
    // 1) mind file
    final targetUrl = await _storage.ref(mindPath).getDownloadURL();

    // 2) list files in /ar
    final listResult = await _storage.ref(folderPath).listAll();

    // 3) filter image files that match img_#.png/jpg/jpeg
    final imgRefs = listResult.items.where((ref) {
      final name = ref.name.toLowerCase();
      return RegExp(r'^img_\d+\.(png|jpg|jpeg)$').hasMatch(name);
    }).toList();

    // 4) sort by the number in img_#.ext
    int imgNumber(Reference r) {
      final m = RegExp(r'^img_(\d+)\.').firstMatch(r.name.toLowerCase());
      return m == null ? 1 << 30 : int.parse(m.group(1)!);
    }

    imgRefs.sort((a, b) => imgNumber(a).compareTo(imgNumber(b)));

    // 5) get download URLs
    final urls = <String, String>{'target': targetUrl};

    for (int i = 0; i < imgRefs.length; i++) {
      final url = await imgRefs[i].getDownloadURL();
      urls['img${i + 1}'] = url; // img1, img2, img3... in order
    }

    return urls;
  }
}

