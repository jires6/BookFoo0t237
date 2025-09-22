import 'package:shared_preferences/shared_preferences.dart';

/// Utilitaire de chiffrement simple pour données sensibles
class SecureStorage {
  static const String _key = 'BkFt237SecK3y'; // Clé de chiffrement simple

  /// Chiffre une chaîne avec XOR simple
  static String _encrypt(String data) {
    final keyBytes = _key.codeUnits;
    final dataBytes = data.codeUnits;
    final encrypted = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return encrypted.map((e) => e.toString().padLeft(3, '0')).join();
  }

  /// Déchiffre une chaîne chiffrée avec XOR
  static String _decrypt(String encryptedData) {
    try {
      final parts = <String>[];
      for (int i = 0; i < encryptedData.length; i += 3) {
        parts.add(encryptedData.substring(i, i + 3));
      }

      final keyBytes = _key.codeUnits;
      final decrypted = <int>[];

      for (int i = 0; i < parts.length; i++) {
        final encryptedByte = int.parse(parts[i]);
        decrypted.add(encryptedByte ^ keyBytes[i % keyBytes.length]);
      }

      return String.fromCharCodes(decrypted);
    } catch (e) {
      return '';
    }
  }

  /// Stocke une donnée sensible de façon sécurisée
  static Future<void> setSecure(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = _encrypt(value);
    await prefs.setString('sec_$key', encrypted);
  }

  /// Récupère une donnée sensible stockée
  static Future<String?> getSecure(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('sec_$key');
    if (encrypted == null) return null;
    return _decrypt(encrypted);
  }

  /// Supprime une donnée sensible
  static Future<void> removeSecure(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sec_$key');
  }
}