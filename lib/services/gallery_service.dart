import 'package:gal/gal.dart';

class GalleryPermissionException implements Exception {
  const GalleryPermissionException();

  @override
  String toString() =>
      'Photos permission denied. Enable it in Settings > MY Cam > Photos.';
}

/// Saves finished photos straight to the iPhone Camera Roll.
class GalleryService {
  GalleryService._();

  static Future<bool> ensureAccess() async {
    if (await Gal.hasAccess()) return true;
    return Gal.requestAccess();
  }

  static Future<void> saveImage(String path) async {
    if (!await ensureAccess()) {
      throw const GalleryPermissionException();
    }
    await Gal.putImage(path);
  }
}
