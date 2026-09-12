import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  Future<bool> ensureMicrophone() => _ensure(Permission.microphone);

  Future<bool> ensureCamera() => _ensure(Permission.camera);

  Future<bool> ensureContacts() => _ensure(Permission.contacts);

  Future<bool> ensurePhone() async {
    if (!Platform.isAndroid) return true;
    return _ensure(Permission.phone);
  }

  Future<bool> _ensure(Permission permission) async {
    final current = await permission.status;
    if (current.isGranted) return true;
    final result = await permission.request();
    return result.isGranted;
  }
}
