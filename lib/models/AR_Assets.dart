import 'package:firebase_storage/firebase_storage.dart';

class ARAssets {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Fetches the mind target + all 3d images (model_1.glb, model_2.glb, ...)
  /// automatically from Storage folder: ar/
    static Future<Map<String, String>> fetchArUrls({
      String mindPath = 'ar/targets_new.mind',
      String folderPath = 'ar',
    }) 
    async {
    final targetUrl = await _storage.ref(mindPath).getDownloadURL();
    final listResult = await _storage.ref(folderPath).listAll();

    final modelRefs = listResult.items.where((ref) {
      return RegExp(r'^model_\d+\.glb$').hasMatch(ref.name.toLowerCase());
    }).toList();

    modelRefs.sort((a, b) {
      int n(Reference r) {
        final m = RegExp(r'^model_(\d+)\.').firstMatch(r.name.toLowerCase());
        return m == null ? 1 << 30 : int.parse(m.group(1)!);
      }
      return n(a).compareTo(n(b));
    });

    final urls = <String, String>{'target': targetUrl};

    for (int i = 0; i < modelRefs.length; i++) {
      urls['model${i + 1}'] = await modelRefs[i].getDownloadURL();
    }

    return urls;
  }

}

