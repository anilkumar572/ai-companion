import 'package:flutter_contacts/flutter_contacts.dart';

import 'permissions_service.dart';

class ContactMatch {
  const ContactMatch({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
  });

  final String id;
  final String displayName;
  final String phoneNumber;
}

class ContactsService {
  ContactsService({PermissionsService? permissions})
      : _permissions = permissions ?? PermissionsService();

  final PermissionsService _permissions;

  Future<bool> _ensureAccess() => _permissions.ensureContacts();

  Future<List<ContactMatch>> searchByName(String query) async {
    if (!await _ensureAccess()) {
      throw ContactsPermissionException();
    }

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final matches = <ContactMatch>[];
    for (final contact in contacts) {
      final name = contact.displayName.trim();
      if (name.isEmpty) continue;

      final nameLower = name.toLowerCase();
      final isMatch = nameLower.contains(normalizedQuery) ||
          normalizedQuery.contains(nameLower) ||
          _tokenMatch(nameLower, normalizedQuery);

      if (!isMatch) continue;

      final phone = _primaryPhone(contact);
      if (phone == null) continue;

      matches.add(
        ContactMatch(
          id: contact.id,
          displayName: name,
          phoneNumber: phone,
        ),
      );
    }

    matches.sort((a, b) {
      final aExact = a.displayName.toLowerCase() == normalizedQuery;
      final bExact = b.displayName.toLowerCase() == normalizedQuery;
      if (aExact != bExact) return aExact ? -1 : 1;
      return a.displayName.length.compareTo(b.displayName.length);
    });

    return matches;
  }

  Future<List<ContactMatch>> listRecent({int limit = 8}) async {
    if (!await _ensureAccess()) {
      throw ContactsPermissionException();
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final matches = <ContactMatch>[];
    for (final contact in contacts) {
      final phone = _primaryPhone(contact);
      if (phone == null) continue;
      matches.add(
        ContactMatch(
          id: contact.id,
          displayName: contact.displayName,
          phoneNumber: phone,
        ),
      );
      if (matches.length >= limit) break;
    }
    return matches;
  }

  String? _primaryPhone(Contact contact) {
    if (contact.phones.isEmpty) return null;
    final phone = contact.phones.first.number.replaceAll(RegExp(r'\s+'), '');
    return phone.isEmpty ? null : phone;
  }

  bool _tokenMatch(String name, String query) {
    final nameTokens = name.split(RegExp(r'\s+'));
    final queryTokens = query.split(RegExp(r'\s+'));
    return queryTokens.every(
      (token) => nameTokens.any((part) => part.startsWith(token)),
    );
  }
}

class ContactsPermissionException implements Exception {}
