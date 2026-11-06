import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../application/quick_evidence.dart';

/// [QuickEvidence] with the device camera (`image_picker`) and microphone
/// (`record`). Files stay in the private folder of the app.
class DeviceQuickEvidence implements QuickEvidence {
  DeviceQuickEvidence({ImagePicker? picker, AudioRecorder? recorder})
    : _picker = picker ?? ImagePicker(),
      _recorder = recorder ?? AudioRecorder();

  final ImagePicker _picker;
  final AudioRecorder _recorder;

  @override
  Future<String?> takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (photo == null) return null;
    final target = await _newFile('photo', p.extension(photo.path));
    await File(photo.path).copy(target);
    return target;
  }

  @override
  Future<bool> startAudio() async {
    if (!await _recorder.hasPermission()) return false;
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: await _newFile('audio', '.m4a'),
    );
    return true;
  }

  @override
  Future<String?> stopAudio() => _recorder.stop();

  static Future<String> _newFile(String prefix, String extension) async {
    final directory = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(directory.path, 'evidence'));
    await folder.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(folder.path, '${prefix}_$stamp$extension');
  }
}
