import 'package:image_picker/image_picker.dart';

enum PhotoSource { gallery, camera }

/// Lets the user pick a picture. Behind an interface so tests can use a fake.
abstract class PhotoPicker {
  /// The path of the chosen picture, or null if the user cancelled.
  Future<String?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<String?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      // A profile picture does not need to be big: smaller = less storage.
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    return file?.path;
  }
}
