import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Service de gestion du stockage d'images avec Supabase
/// Remplace Firebase Storage pour une meilleure performance et économie
class SupabaseStorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ===================================
  // UPLOAD D'IMAGES
  // ===================================

  /// Upload une image vers Supabase Storage
  /// [file] - Fichier image à uploader
  /// [bucketName] - Nom du bucket (stadium-images, profile-images)
  /// [fileName] - Nom du fichier (optionnel, génère automatiquement si null)
  /// Retourne l'URL publique de l'image uploadée
  static Future<String> uploadImage({
    required File file,
    required String bucketName,
    String? fileName,
  }) async {
    try {
      // Vérifier la configuration
      if (!SupabaseConfig.isConfigured) {
        throw Exception('Supabase n\'est pas configuré. Vérifiez lib/config/supabase_config.dart');
      }

      // Vérifier la taille du fichier
      final fileSize = await file.length();
      if (fileSize > SupabaseConfig.maxImageSize) {
        throw Exception('Image trop volumineuse. Taille max: ${SupabaseConfig.maxImageSize / (1024 * 1024)}MB');
      }

      // Générer un nom de fichier unique si non fourni
      fileName ??= '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';

      // Lire les données du fichier
      final Uint8List fileBytes = await file.readAsBytes();

      // Upload vers Supabase Storage
      print('📤 Upload image vers Supabase: $bucketName/$fileName');

      final response = await _supabase.storage
          .from(bucketName)
          .uploadBinary(fileName, fileBytes);

      if (response.isNotEmpty) {
        // Générer l'URL publique
        final publicUrl = SupabaseConfig.getPublicImageUrl(bucketName, fileName);
        print('✅ Image uploadée avec succès: $publicUrl');
        return publicUrl;
      } else {
        throw Exception('Erreur lors de l\'upload: réponse vide');
      }
    } catch (e) {
      print('❌ Erreur upload Supabase: $e');
      rethrow;
    }
  }

  /// Upload plusieurs images en lot
  /// Retourne une Map avec les noms de fichiers et leurs URLs
  static Future<Map<String, String>> uploadMultipleImages({
    required List<File> files,
    required String bucketName,
  }) async {
    final Map<String, String> uploadedImages = {};

    for (int i = 0; i < files.length; i++) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_image_$i.jpg';
        final imageUrl = await uploadImage(
          file: files[i],
          bucketName: bucketName,
          fileName: fileName,
        );
        uploadedImages[fileName] = imageUrl;
      } catch (e) {
        print('❌ Erreur upload image $i: $e');
        // Continue avec les autres images même si une échoue
      }
    }

    return uploadedImages;
  }

  // ===================================
  // SUPPRESSION D'IMAGES
  // ===================================

  /// Supprime une image de Supabase Storage
  /// [imageUrl] - URL complète de l'image à supprimer
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extraire le nom du fichier et bucket de l'URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Format attendu: /storage/v1/object/public/[bucket]/[fileName]
      if (pathSegments.length < 6 || pathSegments[0] != 'storage') {
        throw Exception('URL invalide: $imageUrl');
      }

      final bucketName = pathSegments[4]; // bucket name
      final fileName = pathSegments.sublist(5).join('/'); // file path

      print('🗑️ Suppression image: $bucketName/$fileName');

      final response = await _supabase.storage
          .from(bucketName)
          .remove([fileName]);

      if (response.isNotEmpty) {
        print('✅ Image supprimée avec succès');
        return true;
      } else {
        print('⚠️ Image non trouvée ou déjà supprimée');
        return false;
      }
    } catch (e) {
      print('❌ Erreur suppression Supabase: $e');
      return false;
    }
  }

  /// Supprime plusieurs images en lot
  static Future<Map<String, bool>> deleteMultipleImages(List<String> imageUrls) async {
    final Map<String, bool> results = {};

    for (final url in imageUrls) {
      results[url] = await deleteImage(url);
    }

    return results;
  }

  // ===================================
  // GESTION DES BUCKETS
  // ===================================

  /// Créer les buckets nécessaires (à appeler une seule fois)
  static Future<void> initializeBuckets() async {
    try {
      final buckets = [
        SupabaseConfig.stadiumImagesBucket,
        SupabaseConfig.profileImagesBucket,
      ];

      for (final bucketName in buckets) {
        try {
          await _supabase.storage.createBucket(bucketName, BucketOptions(
            public: true, // Images publiques
            allowedMimeTypes: SupabaseConfig.allowedImageTypes,
            fileSizeLimit: SupabaseConfig.maxImageSizeString,
          ));
          print('✅ Bucket créé: $bucketName');
        } catch (e) {
          // Bucket existe déjà
          print('ℹ️ Bucket déjà existant: $bucketName');
        }
      }
    } catch (e) {
      print('❌ Erreur initialisation buckets: $e');
    }
  }

  // ===================================
  // UTILITAIRES
  // ===================================

  /// Vérifie si une image existe
  static Future<bool> imageExists(String bucketName, String fileName) async {
    try {
      await _supabase.storage.from(bucketName).info(fileName);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtient les métadonnées d'une image
  static Future<Map<String, dynamic>?> getImageInfo(String bucketName, String fileName) async {
    try {
      final info = await _supabase.storage.from(bucketName).info(fileName);
      return {
        'name': info.name,
        'size': info.metadata?['size'],
        'contentType': info.metadata?['mimetype'],
        'lastModified': info.updatedAt,
      };
    } catch (e) {
      print('❌ Erreur récupération info image: $e');
      return null;
    }
  }

  /// Liste toutes les images d'un bucket
  static Future<List<String>> listImages(String bucketName, {String? folder}) async {
    try {
      final response = await _supabase.storage.from(bucketName).list(path: folder);
      return response.map((item) => item.name).toList();
    } catch (e) {
      print('❌ Erreur liste images: $e');
      return [];
    }
  }
}