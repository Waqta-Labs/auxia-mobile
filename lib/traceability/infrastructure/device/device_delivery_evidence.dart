import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../application/delivery_evidence.dart';

/// [DeliveryEvidence] in the private folder of the app.
class DeviceDeliveryEvidence implements DeliveryEvidence {
  DeviceDeliveryEvidence({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1920,
    );
    if (photo == null) return null;
    final target = await _newFile('reception', '.jpg');
    await File(photo.path).copy(target);
    return target;
  }

  @override
  Future<String> saveSignature(Uint8List png) async {
    final target = await _newFile('signature', '.png');
    await File(target).writeAsBytes(png, flush: true);
    return target;
  }

  static Future<String> _newFile(String prefix, String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'deliveries'));
    await folder.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(folder.path, '${prefix}_$stamp$extension');
  }
}
