import 'package:image_picker/image_picker.dart';

import 'permissions_service.dart';

class CameraCaptureResult {
  const CameraCaptureResult({
    required this.path,
    required this.isVideo,
  });

  final String path;
  final bool isVideo;
}

class CameraService {
  CameraService({PermissionsService? permissions})
      : _permissions = permissions ?? PermissionsService(),
        _picker = ImagePicker();

  final PermissionsService _permissions;
  final ImagePicker _picker;

  Future<CameraCaptureResult?> takePhoto() async {
    final granted = await _permissions.ensureCamera();
    if (!granted) {
      throw CameraPermissionException();
    }

    final file = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );

    if (file == null) return null;
    return CameraCaptureResult(path: file.path, isVideo: false);
  }

  Future<CameraCaptureResult?> recordVideo() async {
    final granted = await _permissions.ensureCamera();
    if (!granted) {
      throw CameraPermissionException();
    }

    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxDuration: const Duration(minutes: 2),
    );

    if (file == null) return null;
    return CameraCaptureResult(path: file.path, isVideo: true);
  }
}

class CameraPermissionException implements Exception {}
