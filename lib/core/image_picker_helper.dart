import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Picks and aggressively compresses images client-side before uploading.
  /// Reduces 8MB+ camera/gallery photos down to ~30KB–50KB (saves ~98% egress bandwidth).
  static Future<XFile?> pickAndCompressImage({
    required ImageSource source,
    double maxWidth = 600,
    double maxHeight = 600,
    int imageQuality = 65,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      
      if (image != null) {
        debugPrint('ImagePickerHelper: Image picked and compressed locally at ${image.path}');
      }
      return image;
    } catch (e) {
      debugPrint('ImagePickerHelper Error: $e');
      return null;
    }
  }
}
