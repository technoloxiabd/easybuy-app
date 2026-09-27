import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Turns a chosen source into local file paths. Photos are scaled down on the
/// phone first: a 12-megapixel screenshot of a bank receipt is 5 MB on mobile
/// data for no gain, and the server caps uploads at 5 MB each.
Future<List<String>> pickFrom(String? source, {bool allowVideo = true}) async {
  final picker = ImagePicker();
  switch (source) {
    case 'camera':
      final shot = await picker.pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 82);
      return shot == null ? const [] : [shot.path];
    case 'gallery':
      final shots = await picker.pickMultiImage(maxWidth: 2000, imageQuality: 82, limit: 5);
      return shots.map((x) => x.path).toList();
    case 'file':
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', if (allowVideo) ...['mp4', 'mov', 'webm']],
      );
      return files.map((f) => f.path).whereType<String>().toList();
    default:
      return const [];
  }
}
