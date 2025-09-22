/// Système de logging centralisé pour l'application
class AppLogger {
  static const bool _isDebugMode = false; // Changez à true pour debug

  static void debug(String message) {
    if (_isDebugMode) {
      print('🔍 DEBUG: $message');
    }
  }

  /// Log sécurisé pour tokens/données sensibles
  static void secureInfo(String message, String? sensitiveData) {
    if (_isDebugMode) {
      print('🔒 SECURE: $message ${sensitiveData ?? '[MASKED]'}');
    } else {
      print('🔒 SECURE: $message [MASKED]');
    }
  }

  static void info(String message) {
    print('ℹ️ INFO: $message');
  }

  static void warning(String message) {
    print('⚠️ WARNING: $message');
  }

  static void error(String message, [dynamic error]) {
    print('❌ ERROR: $message${error != null ? ' - $error' : ''}');
  }

  static void success(String message) {
    print('✅ SUCCESS: $message');
  }
}