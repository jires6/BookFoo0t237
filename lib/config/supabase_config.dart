/// Configuration Supabase pour BookFoot237
///
/// IMPORTANT: Remplacez les valeurs par vos vraies clés Supabase!
/// 1. Créez un projet sur https://supabase.com
/// 2. Récupérez votre URL et clé anonyme
/// 3. Remplacez les valeurs ci-dessous

class SupabaseConfig {
  // ===================================
  // CONFIGURATION SUPABASE
  // ===================================

  /// URL de votre projet Supabase
  /// Trouvez-la dans: Supabase Dashboard > Settings > API
  static const String supabaseUrl = 'https://jxenudxbhmjgwpvvwlxz.supabase.co';

  /// Clé anonyme (publique) de votre projet Supabase
  /// Trouvez-la dans: Supabase Dashboard > Settings > API > anon public
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4ZW51ZHhiaG1qZ3dwdnZ3bHh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg0Nzc5ODMsImV4cCI6MjA3NDA1Mzk4M30.v9bJ_0IORyiVJIOZP7nDUh6VgTSd5gv2CHPRvYKPXtE';

  // ===================================
  // CONFIGURATION BUCKET STORAGE
  // ===================================

  /// Nom du bucket pour les images de stades
  /// Créez ce bucket dans: Supabase Dashboard > Storage
  static const String stadiumImagesBucket = 'bucketBookFoot237';

  /// Nom du bucket pour les photos de profil
  static const String profileImagesBucket = 'profile-images';

  // ===================================
  // POLITIQUE DE STOCKAGE
  // ===================================

  /// Taille maximale des images (en bytes)
  /// 5MB = 5 * 1024 * 1024 bytes
  static const int maxImageSize = 5 * 1024 * 1024;

  /// Taille maximale en string pour Supabase
  static const String maxImageSizeString = '5242880';

  /// Types de fichiers autorisés
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp'
  ];

  // ===================================
  // MÉTHODES D'AIDE
  // ===================================

  /// Retourne true si la configuration Supabase est complète
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseUrl != 'https://jxenudxbhmjgwpvvwlxz.supabase.co' &&
        supabaseAnonKey.isNotEmpty &&
        supabaseAnonKey !=
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4ZW51ZHhiaG1qZ3dwdnZ3bHh6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg0Nzc5ODMsImV4cCI6MjA3NDA1Mzk4M30.v9bJ_0IORyiVJIOZP7nDUh6VgTSd5gv2CHPRvYKPXtE';
  }

  /// URL complète pour accéder aux images
  static String getPublicImageUrl(String bucketName, String fileName) {
    return '$supabaseUrl/storage/v1/object/public/$bucketName/$fileName';
  }
}
