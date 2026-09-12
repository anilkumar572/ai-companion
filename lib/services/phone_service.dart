import 'package:url_launcher/url_launcher.dart';

import 'permissions_service.dart';

class PhoneService {
  PhoneService({PermissionsService? permissions})
      : _permissions = permissions ?? PermissionsService();

  final PermissionsService _permissions;

  Future<bool> callNumber(String rawNumber) async {
    await _permissions.ensurePhone();
    final number = _sanitize(rawNumber);
    if (number.isEmpty) {
      throw PhoneNumberException('The phone number is invalid.');
    }

    final uri = Uri(scheme: 'tel', path: number);
    final launched = await launchUrl(uri);
    if (!launched) {
      throw PhoneLaunchException();
    }
    return true;
  }

  String _sanitize(String raw) {
    return raw.replaceAll(RegExp(r'[^\d+]+'), '');
  }
}

class PhoneNumberException implements Exception {
  PhoneNumberException(this.message);
  final String message;
}

class PhoneLaunchException implements Exception {}
