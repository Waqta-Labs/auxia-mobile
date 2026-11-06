import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Takes the photo of the institutional ID card (A_02, "Escanear carnet
/// institucional") and keeps it in the private folder of the app.
class IdCardCamera {
  IdCardCamera({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Returns the local path of the photo, or null if the user cancelled.
  Future<String?> capture() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (photo == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'credentials'));
    await folder.create(recursive: true);
    final target = p.join(folder.path, 'id_card${p.extension(photo.path)}');
    await File(photo.path).copy(target);
    return target;
  }
}
