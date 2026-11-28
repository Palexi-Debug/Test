import 'dart:io' show Platform;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liblanis/liblanis.dart';

/// [SecretStore] backed by [FlutterSecureStorage].
///
/// Auf unsignierten macOS-Builds (`--no-codesign`, kein Apple-Zertifikat) wirft
/// die Keychain `errSecMissingEntitlement` (-34018). Dann wird für die Dauer
/// der Sitzung auf einen Speicher im Arbeitsspeicher ausgewichen, damit der
/// Login nicht scheitert (Zugangsdaten bleiben dann nicht über einen Neustart
/// erhalten).
class FlutterSecretStore implements SecretStore {
  FlutterSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;

  static final Map<String, String> _memory = {};
  static bool _useMemory = false;

  static bool _isEntitlementError(Object e) {
    if (!Platform.isMacOS) return false;
    final text = e is PlatformException
        ? '${e.code} ${e.message} ${e.details}'
        : e.toString();
    return text.contains('-34018') ||
        text.contains('errSecMissingEntitlement') ||
        text.contains('required entitlement');
  }

  @override
  Future<void> write(String key, String value) async {
    if (!_useMemory) {
      try {
        await _storage.write(key: key, value: value);
        return;
      } catch (e) {
        if (!_isEntitlementError(e)) rethrow;
        _useMemory = true;
      }
    }
    _memory[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    if (!_useMemory) {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        if (!_isEntitlementError(e)) rethrow;
        _useMemory = true;
      }
    }
    return _memory[key];
  }

  @override
  Future<void> delete(String key) async {
    if (!_useMemory) {
      try {
        await _storage.delete(key: key);
        return;
      } catch (e) {
        if (!_isEntitlementError(e)) rethrow;
        _useMemory = true;
      }
    }
    _memory.remove(key);
  }

  Future<void> deleteAll() async {
    if (!_useMemory) {
      try {
        await _storage.deleteAll();
        return;
      } catch (e) {
        if (!_isEntitlementError(e)) rethrow;
        _useMemory = true;
      }
    }
    _memory.clear();
  }
}
