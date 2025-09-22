import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_storage_service.dart';
import '../config/supabase_config.dart';
import '../utils/app_logger.dart';

class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();

  /// Upload une image vers Supabase Storage
  static Future<String?> uploadImage(XFile imageFile, String stadiumId) async {
    try {
      final File file = File(imageFile.path);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';

      final String url = await SupabaseStorageService.uploadImage(
        file: file,
        bucketName: SupabaseConfig.stadiumImagesBucket,
        fileName: fileName,
      );

      AppLogger.info('Image uploadée avec succès: $url');
      return url;
    } catch (e) {
      AppLogger.error('Erreur lors de l\'upload d\'image: $e');
      return null;
    }
  }

  /// Sélectionner et uploader plusieurs images
  static Future<List<String>> selectAndUploadImages(String stadiumId,
      {int maxImages = 5}) async {
    try {
      print('🖼️ ImageUploadService.selectAndUploadImages appelé pour stadiumId: $stadiumId');

      final List<XFile> imageFiles = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      print('📷 Images sélectionnées: ${imageFiles.length}');

      if (imageFiles.isEmpty) {
        print('⚠️ Aucune image sélectionnée par l\'utilisateur');
        return [];
      }

      // Limiter le nombre d'images
      final List<XFile> limitedFiles = imageFiles.take(maxImages).toList();
      final List<String> uploadedUrls = [];

      print('⬆️ Début upload de ${limitedFiles.length} images...');

      for (int i = 0; i < limitedFiles.length; i++) {
        final XFile imageFile = limitedFiles[i];
        print('⬆️ Upload image ${i + 1}/${limitedFiles.length}: ${imageFile.name}');

        final String? url = await uploadImage(imageFile, stadiumId);
        if (url != null) {
          uploadedUrls.add(url);
          print('✅ Image ${i + 1} uploadée: $url');
        } else {
          print('❌ Échec upload image ${i + 1}');
        }
      }

      print('🎉 Upload terminé. ${uploadedUrls.length}/${limitedFiles.length} images uploadées');
      print('📋 URLs finales: $uploadedUrls');
      return uploadedUrls;
    } catch (e) {
      print('❌ Erreur lors de la sélection d\'images: $e');
      AppLogger.error('Erreur lors de la sélection d\'images: $e');
      return [];
    }
  }

  /// Prendre une photo avec la caméra
  static Future<String?> takeAndUploadPhoto(String stadiumId) async {
    try {
      final XFile? imageFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (imageFile == null) return null;

      return await uploadImage(imageFile, stadiumId);
    } catch (e) {
      AppLogger.error('Erreur lors de la prise de photo: $e');
      return null;
    }
  }

  /// Supprimer une image de Supabase Storage
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final bool success = await SupabaseStorageService.deleteImage(imageUrl);
      if (success) {
        AppLogger.info('Image supprimée avec succès: $imageUrl');
      }
      return success;
    } catch (e) {
      AppLogger.error('Erreur lors de la suppression d\'image: $e');
      return false;
    }
  }
}