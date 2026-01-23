import 'package:firebase_storage/firebase_storage.dart';

class ARAssets {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<Map<String, String>> fetchArUrls() async {
    final targetUrl =
        await _storage.ref('ar/targets_new.mind').getDownloadURL();

    final img1 = await _storage.ref('ar/img_1.png').getDownloadURL();
    final img2 = await _storage.ref('ar/img_2.png').getDownloadURL();
    final img3 = await _storage.ref('ar/img_3.png').getDownloadURL();
    final img4 = await _storage.ref('ar/img_4.png').getDownloadURL();

    return {
      'target': targetUrl,
      'img1': img1,
      'img2': img2,
      'img3': img3,
      'img4': img4,
    };
  }
}
