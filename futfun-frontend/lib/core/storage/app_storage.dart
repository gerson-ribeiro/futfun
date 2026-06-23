import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Single shared instance with encryptedSharedPreferences to avoid silent
// read failures on Android devices that have issues with the default KeyStore.
const appStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
