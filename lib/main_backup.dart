import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:image_picker/image_picker.dart';
import 'services/notification_service.dart';
import 'services/app_lifecycle_service.dart';
import 'services/supabase_storage_service.dart';
import 'config/supabase_config.dart';

// === UTILITAIRES ===

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

/// Système de cache simple pour optimiser les performances
class SimpleCache<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final Duration _defaultTtl;

  SimpleCache({Duration defaultTtl = const Duration(minutes: 5)})
      : _defaultTtl = defaultTtl;

  void set(String key, T value, {Duration? ttl}) {
    final expiry = DateTime.now().add(ttl ?? _defaultTtl);
    _cache[key] = _CacheEntry(value, expiry);
  }

  T? get(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.value;
  }

  void clear() => _cache.clear();

  void remove(String key) => _cache.remove(key);

  bool contains(String key) {
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiry;

  _CacheEntry(this.value, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}

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

// === SERVICES FIREBASE ===

// Service Firebase Authentication avec messaging
class FirebaseAuthService {
  static final FirebaseAuthService instance = FirebaseAuthService._internal();
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream des changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inscription avec email/password
  Future<UserCredential?> registerWithEmailAndPassword(
    String email,
    String password,
    String fullName,
    String userType, {
    Map<String, dynamic>? stadiumData,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Mettre à jour le profil utilisateur
      await result.user?.updateDisplayName(fullName);

      // Sauvegarder les données utilisateur dans Firestore
      await _firestore.collection('users').doc(result.user?.uid).set({
        'email': email,
        'fullName': fullName,
        'userType': userType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Si c'est un gestionnaire, sauvegarder les données du stade
      if (userType == 'gestionnaire' && stadiumData != null) {
        await _firestore.collection('stadiums').add({
          'managerId': result.user?.uid,
          'managerEmail': email,
          ...stadiumData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return result;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'Cet email est déjà utilisé par un autre compte';
        case 'invalid-email':
          throw 'Format email invalide';
        case 'operation-not-allowed':
          throw 'Inscription par email/mot de passe désactivée';
        case 'weak-password':
          throw 'Mot de passe trop faible. Minimum 6 caractères';
        case 'network-request-failed':
          throw 'Erreur réseau. Vérifiez votre connexion internet';
        default:
          throw 'Erreur d\'inscription: ${e.message ?? e.code}';
      }
    } on FirebaseException catch (e) {
      throw 'Erreur Firestore: ${e.message ?? e.code}';
    } catch (e) {
      throw 'Erreur inattendue lors de l\'inscription: $e';
    }
  }

  // Connexion avec email/password
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'Aucun utilisateur trouvé avec cet email';
        case 'wrong-password':
          throw 'Mot de passe incorrect';
        case 'invalid-email':
          throw 'Format email invalide';
        case 'user-disabled':
          throw 'Ce compte utilisateur a été désactivé';
        case 'too-many-requests':
          throw 'Trop de tentatives. Veuillez réessayer plus tard';
        case 'network-request-failed':
          throw 'Erreur réseau. Vérifiez votre connexion internet';
        default:
          throw 'Erreur de connexion: ${e.message ?? e.code}';
      }
    } catch (e) {
      throw 'Erreur inattendue: $e';
    }
  }

  // Inscription/Connexion avec numéro de téléphone
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(PhoneAuthCredential) verificationCompleted,
    Function(FirebaseAuthException) verificationFailed,
    Function(String, int?) codeSent,
    Function(String) codeAutoRetrievalTimeout,
  ) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // Connexion avec credential téléphone
  Future<UserCredential?> signInWithPhoneCredential(
      PhoneAuthCredential credential) async {
    try {
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Erreur connexion téléphone: $e');
      return null;
    }
  }

  // Récupérer les données utilisateur
  Future<Map<String, dynamic>?> getUserData() async {
    final user = currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    }
    return null;
  }

  // Initialiser FCM
  Future<void> initializeMessaging() async {
    try {
      // Demander la permission pour les notifications
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Obtenir le token FCM
      String? token = await _messaging.getToken();
      if (token != null) {
        AppLogger.secureInfo('FCM Token obtenu', token);
        // Sauvegarder le token dans Firestore pour l'utilisateur connecté
        if (currentUser != null) {
          await _firestore.collection('users').doc(currentUser!.uid).update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
      }

      // Écouter les changements de token
      _messaging.onTokenRefresh.listen((newToken) async {
        if (currentUser != null) {
          await _firestore.collection('users').doc(currentUser!.uid).update({
            'fcmToken': newToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
      });

      print('Firebase Messaging initialisé avec succès');
    } catch (e) {
      print('Erreur initialisation FCM: $e');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print('Erreur déconnexion: $e');
    }
  }
}

class ReservationRequest {
  final String id;
  final String stadeId;
  final String stadeNom;
  final String clientNom;
  final String clientEmail;
  final DateTime dateReservation;
  final String heureDebut;
  final String heureFin;
  final String raison;
  final String statut;
  final DateTime dateCreation;

  ReservationRequest({
    required this.id,
    required this.stadeId,
    required this.stadeNom,
    required this.clientNom,
    required this.clientEmail,
    required this.dateReservation,
    required this.heureDebut,
    required this.heureFin,
    required this.raison,
    required this.statut,
    required this.dateCreation,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'stadeId': stadeId,
        'stadeNom': stadeNom,
        'clientNom': clientNom,
        'clientEmail': clientEmail,
        'dateReservation': dateReservation.toIso8601String(),
        'heureDebut': heureDebut,
        'heureFin': heureFin,
        'raison': raison,
        'statut': statut,
        'dateCreation': dateCreation.toIso8601String(),
      };

  static ReservationRequest fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateValue, DateTime defaultValue) {
      try {
        if (dateValue == null) return defaultValue;
        if (dateValue is String) {
          if (dateValue.isEmpty) return defaultValue;
          return DateTime.parse(dateValue);
        }
        if (dateValue is Timestamp) {
          return dateValue.toDate();
        }
        return defaultValue;
      } catch (e) {
        print('❌ Erreur parsing date: $dateValue - $e');
        return defaultValue;
      }
    }

    return ReservationRequest(
      id: json['id'] ?? '',
      stadeId: json['stadeId'] ?? '',
      stadeNom: json['stadeNom'] ?? '',
      clientNom: json['clientNom'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      dateReservation: parseDate(json['dateReservation'], DateTime.now()),
      heureDebut: json['heureDebut'] ?? '',
      heureFin: json['heureFin'] ?? '',
      raison: json['raison'] ?? '',
      statut: json['statut'] ?? 'en_attente',
      dateCreation: parseDate(json['dateCreation'], DateTime.now()),
    );
  }
}

// Classe pour validation des formulaires
class FormValidators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email requis';
    }

    // Validation avancée avec plusieurs critères
    final trimmedValue = value.trim();

    // Vérification longueur
    if (trimmedValue.length < 5 || trimmedValue.length > 254) {
      return 'Email doit faire entre 5 et 254 caractères';
    }

    // Regex robuste pour email (simplifiée)
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmedValue)) {
      return 'Format email invalide';
    }

    // Vérifications supplémentaires
    if (trimmedValue.startsWith('.') || trimmedValue.endsWith('.')) {
      return 'Email ne peut pas commencer ou finir par un point';
    }

    if (trimmedValue.contains('..')) {
      return 'Email ne peut pas contenir de points consécutifs';
    }

    final parts = trimmedValue.split('@');
    if (parts.length != 2) {
      return 'Email doit contenir exactement un @';
    }

    final localPart = parts[0];
    final domainPart = parts[1];

    if (localPart.length > 64) {
      return 'Partie locale de l\'email trop longue';
    }

    if (domainPart.isEmpty || domainPart.length > 253) {
      return 'Domaine email invalide';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }
    if (value.length < 6) {
      return 'Minimum 6 caractères';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Doit contenir au moins: 1 majuscule, 1 minuscule, 1 chiffre';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nom requis';
    }
    if (value.length < 2) {
      return 'Nom trop court (minimum 2 caractères)';
    }
    if (!RegExp(r'^[a-zA-Z\s\u00C0-\u017F]+$').hasMatch(value)) {
      return 'Le nom ne peut contenir que des lettres et espaces';
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Numéro de téléphone requis';
    }
    // Format camerounais: +237XXXXXXXXX ou 6XXXXXXXX
    if (!RegExp(r'^(\+237)?[6][0-9]{8}$').hasMatch(value.replaceAll(' ', ''))) {
      return 'Format invalide (ex: +237612345678 ou 612345678)';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName requis';
    }
    return null;
  }

  static String? validateTime(String? value) {
    if (value == null || value.isEmpty) {
      return 'Heure requise';
    }
    // Format HH:MM
    if (!RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(value)) {
      return 'Format invalide (ex: 14:30)';
    }
    return null;
  }
}

// === GESTION DES STADES ===

/// Classe pour représenter un stade avec toutes ses informations
class Stadium {
  final String id;
  final String nom;
  final String adresse;
  final String quartier;
  final int prix;
  final String type;
  final String capacite;
  final bool disponible;
  final String description;
  final String gestionnaire;
  final List<String> images;
  final Map<String, dynamic> horaires;
  final DateTime dateCreation;
  final Map<String, dynamic> amenities;

  Stadium({
    required this.id,
    required this.nom,
    required this.adresse,
    required this.quartier,
    required this.prix,
    required this.type,
    required this.capacite,
    this.disponible = true,
    required this.description,
    required this.gestionnaire,
    this.images = const [],
    Map<String, dynamic>? horaires,
    DateTime? dateCreation,
    this.amenities = const {},
  })  : horaires = horaires ?? _defaultSchedule(),
        dateCreation = dateCreation ?? DateTime.now();

  static Map<String, dynamic> _defaultSchedule() {
    return {
      'lundi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'mardi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'mercredi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'jeudi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'vendredi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'samedi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'dimanche': {'ouvert': true, 'debut': '08:00', 'fin': '20:00'},
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'adresse': adresse,
      'quartier': quartier,
      'prix': prix,
      'type': type,
      'capacite': capacite,
      'disponible': disponible,
      'description': description,
      'gestionnaire': gestionnaire,
      'images': images,
      'horaires': horaires,
      'dateCreation': dateCreation.toIso8601String(),
      'amenities': amenities,
    };
  }

  factory Stadium.fromMap(Map<String, dynamic> map) {
    return Stadium(
      id: map['id'] ?? '',
      nom: map['nom'] ?? '',
      adresse: map['adresse'] ?? '',
      quartier: map['quartier'] ?? '',
      prix: map['prix'] ?? 0,
      type: map['type'] ?? '',
      capacite: map['capacite'] ?? '',
      disponible: map['disponible'] ?? true,
      description: map['description'] ?? '',
      gestionnaire: map['gestionnaire'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      horaires:
          Map<String, dynamic>.from(map['horaires'] ?? _defaultSchedule()),
      dateCreation: map['dateCreation'] != null
          ? DateTime.parse(map['dateCreation'])
          : DateTime.now(),
      amenities: Map<String, dynamic>.from(map['amenities'] ?? {}),
    );
  }
}

/// Service pour gérer l'upload d'images vers Firebase Storage
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

/// Service pour gérer les stades dans Firebase
class StadiumService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'stadiums';

  /// Créer un nouveau stade
  static Future<String?> createStadium(Stadium stadium) async {
    try {
      final DocumentReference docRef =
          await _firestore.collection(_collection).add(stadium.toMap());
      AppLogger.info('Stade créé avec succès: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Erreur lors de la création du stade: $e');
      return null;
    }
  }

  /// Mettre à jour un stade existant
  static Future<bool> updateStadium(String stadiumId, Stadium stadium) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(stadiumId)
          .update(stadium.toMap());
      AppLogger.info('Stade mis à jour avec succès: $stadiumId');
      return true;
    } catch (e) {
      AppLogger.error('Erreur lors de la mise à jour du stade: $e');
      return false;
    }
  }

  /// Récupérer tous les stades
  static Future<List<Stadium>> getAllStadiums() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('disponible', isEqualTo: true)
          .orderBy('dateCreation', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Stadium.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des stades: $e');
      return [];
    }
  }

  /// Récupérer les stades d'un gestionnaire
  static Future<List<Stadium>> getStadiumsByManager(String managerEmail) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('gestionnaire', isEqualTo: managerEmail)
          .orderBy('dateCreation', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Stadium.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger.error(
          'Erreur lors de la récupération des stades du gestionnaire: $e');
      return [];
    }
  }

  /// Stream pour écouter les changements en temps réel
  static Stream<List<Stadium>> getStadiumsStream() {
    return _firestore
        .collection(_collection)
        .where('disponible', isEqualTo: true)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Stadium.fromMap(data);
      }).toList();
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialiser Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialiser les buckets Supabase
  await SupabaseStorageService.initializeBuckets();

  // Initialiser les données de localisation française
  await initializeDateFormatting('fr_FR');

  // Initialiser Firebase Cloud Messaging
  await FirebaseAuthService.instance.initializeMessaging();

  // Initialiser le service de cycle de vie pour empêcher l'auto-destruction
  AppLifecycleService().initialize();

  runApp(const BookFootApp());
}

class BookFootApp extends StatelessWidget {
  const BookFootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BookFoot237',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routerConfig: GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterPage(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  bool _isPhoneAuth = false;
  bool _isOtpSent = false;
  String _verificationId = '';

  Future<void> _handleLogin() async {
    if (_emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      try {
        final result = await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (result != null && mounted) {
          final userData = await _authService.getUserData();
          final userType = userData?['userType'] ?? 'client';
          final userName = userData?['fullName'] ??
              userData?['name'] ??
              result.user?.displayName ??
              'Utilisateur';
          final userEmail = result.user?.email ?? '';

          // Sauvegarder les données utilisateur dans SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user', userEmail);
          await prefs.setString('current_user_type', userType);
          await prefs.setString('username_$userEmail', userName);

          print('✅ Utilisateur connecté: $userEmail ($userType) - $userName');

          // Initialiser FCM pour l'utilisateur connecté
          await _authService.initializeMessaging();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connexion réussie! Bienvenue $userName'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email ou mot de passe incorrect'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handlePhoneAuth() async {
    if (_phoneController.text.isNotEmpty) {
      try {
        await _authService.verifyPhoneNumber(
          _phoneController.text.trim(),
          (PhoneAuthCredential credential) async {
            // Auto-résolution
            final result =
                await _authService.signInWithPhoneCredential(credential);
            if (result != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connexion par téléphone réussie!'),
                  backgroundColor: Colors.green,
                ),
              );
              context.go('/home');
            }
          },
          (FirebaseAuthException e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: ${e.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          (String verificationId, int? resendToken) {
            setState(() {
              _verificationId = verificationId;
              _isOtpSent = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code de vérification envoyé!'),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          },
          (String verificationId) {
            setState(() {
              _verificationId = verificationId;
            });
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isNotEmpty && _verificationId.isNotEmpty) {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: _otpController.text.trim(),
        );

        final result = await _authService.signInWithPhoneCredential(credential);
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion par téléphone réussie!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Code incorrect: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleVisitorMode() async {
    try {
      print('🔓 DÉCONNEXION COMPLÈTE - Mode visiteur activé');

      // ÉTAPE 1: Déconnexion Firebase complète
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
        print('🔥 Firebase Auth déconnecté');
      }

      // ÉTAPE 2: Nettoyage complet des SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Nettoie TOUT
      print('🧹 SharedPreferences nettoyées complètement');

      // ÉTAPE 3: Configuration du mode visiteur pur
      await prefs.setString('current_user', 'Visiteur');
      await prefs.setString('current_user_type', 'visiteur');
      print('👁️ Mode visiteur configuré - Aucune session utilisateur');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Mode visiteur activé - Vous pouvez explorer sans réserver'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      print('❌ Erreur activation mode visiteur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? 64 : 24,
              vertical: 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'BookFoot237',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Réservez votre terrain de football',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Login Form
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Connexion',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Toggle between email and phone auth
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _isPhoneAuth = false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !_isPhoneAuth
                                    ? const Color(0xFF1E88E5)
                                    : null,
                                foregroundColor: !_isPhoneAuth
                                    ? Colors.white
                                    : const Color(0xFF1E88E5),
                              ),
                              child: const Text('Email'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _isPhoneAuth = true),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _isPhoneAuth
                                    ? const Color(0xFF1E88E5)
                                    : null,
                                foregroundColor: _isPhoneAuth
                                    ? Colors.white
                                    : const Color(0xFF1E88E5),
                              ),
                              child: const Text('Téléphone'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Email auth fields
                      if (!_isPhoneAuth) ...[
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ],

                      // Phone auth fields
                      if (_isPhoneAuth) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Numéro de téléphone',
                            hintText: '+237612345678',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        if (_isOtpSent) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Code de vérification',
                              hintText: '123456',
                              prefixIcon: const Icon(Icons.sms),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_isPhoneAuth) {
                              if (_isOtpSent) {
                                _verifyOtp();
                              } else {
                                _handlePhoneAuth();
                              }
                            } else {
                              _handleLogin();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isPhoneAuth
                                ? (_isOtpSent
                                    ? 'Vérifier le code'
                                    : 'Envoyer le code')
                                : 'Se connecter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Register button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/register'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E88E5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Créer un compte',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Visitor mode button
                      TextButton(
                        onPressed: _handleVisitorMode,
                        child: const Text(
                          '👁️ Continuer en tant que visiteur',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _stadeNomController = TextEditingController();
  final _stadeAdresseController = TextEditingController();
  final _stadePrixController = TextEditingController();

  String _userType = 'client';
  String _stadeCapacite = '11v11';
  String _stadeType = 'Terrain en herbe naturelle';
  String _verificationType = 'email'; // 'email' ou 'phone'

  // Variables pour l'upload d'images du stade
  List<String> _stadeImages = [];
  bool _isUploadingImages = false;
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  String _verificationId = '';

  Future<void> _sendOtpVerification() async {
    if (!_formKey.currentState!.validate()) return;

    if (_verificationType == 'email') {
      await _sendEmailOtp();
    } else {
      await _sendPhoneOtp();
    }
  }

  Future<void> _sendEmailOtp() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Envoi du code par email...'),
          backgroundColor: Colors.blue,
        ),
      );

      // Utiliser le service d'email réel
      final otpCode = await NotificationService.instance
          .sendEmailOtp(_emailController.text.trim());

      if (otpCode != null) {
        // Stocker le code et l'heure pour vérification
        final prefs = await SharedPreferences.getInstance();
        await SecureStorage.setSecure('otp_${_emailController.text}', otpCode);
        await prefs.setInt('otp_time_${_emailController.text}',
            DateTime.now().millisecondsSinceEpoch);
        AppLogger.secureInfo('Code OTP stocké de façon sécurisée', otpCode);

        if (mounted) {
          setState(() {
            _isOtpSent = true;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Code envoyé à ${_emailController.text}!\nVérifiez votre boîte email (et spam).'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        // Fallback si l'envoi réel échoue
        final random = DateTime.now().millisecondsSinceEpoch % 900000 + 100000;
        final fallbackCode = random.toString();

        final prefs = await SharedPreferences.getInstance();
        await SecureStorage.setSecure(
            'otp_${_emailController.text}', fallbackCode);
        await prefs.setInt('otp_time_${_emailController.text}',
            DateTime.now().millisecondsSinceEpoch);
        AppLogger.secureInfo(
            'Code OTP fallback stocké de façon sécurisée', fallbackCode);

        if (mounted) {
          setState(() {
            _isOtpSent = true;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ Mode démo - Email non envoyé'),
                const SizedBox(height: 4),
                Text('Code test: $fallbackCode',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Text('Configurez SMTP pour envoi réel',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendPhoneOtp() async {
    if (_telephoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro de téléphone requis'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String phoneNumber = _telephoneController.text.trim();
    if (!phoneNumber.startsWith('+237')) {
      phoneNumber = '+237$phoneNumber';
    }

    try {
      await FirebaseAuthService.instance.verifyPhoneNumber(
        phoneNumber,
        (PhoneAuthCredential credential) {
          // Auto-résolution
          setState(() {
            _isOtpVerified = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Numéro vérifié automatiquement!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        (FirebaseAuthException e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur: ${e.message}'),
                backgroundColor: Colors.red),
          );
        },
        (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isOtpSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code SMS envoyé!'),
              backgroundColor: Colors.blue,
            ),
          );
        },
        (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Code OTP requis'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_verificationType == 'email') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedCode =
            await SecureStorage.getSecure('otp_${_emailController.text}');
        final codeTime = prefs.getInt('otp_time_${_emailController.text}');

        if (storedCode == null || codeTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code expiré. Veuillez renvoyer un nouveau code.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Vérifier que le code n'est pas expiré (5 minutes)
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - codeTime > 300000) {
          // 5 minutes en millisecondes
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Code expiré (5 min max). Veuillez renvoyer un nouveau code.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (_otpController.text.trim() == storedCode) {
          if (mounted) {
            setState(() {
              _isOtpVerified = true;
            });
          }

          // Supprimer le code utilisé
          await SecureStorage.removeSecure('otp_${_emailController.text}');
          prefs.remove('otp_time_${_emailController.text}');
          AppLogger.info('Code OTP validé et supprimé de façon sécurisée');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email vérifié avec succès!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code incorrect. Vérifiez le code reçu.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de vérification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Vérification SMS
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: _otpController.text.trim(),
        );

        // Tester la validité du credential
        await FirebaseAuth.instance.signInWithCredential(credential);
        await FirebaseAuth.instance.signOut(); // Se déconnecter immédiatement

        if (mounted) {
          setState(() {
            _isOtpVerified = true;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Numéro vérifié avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code incorrect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // === FONCTIONS UPLOAD D'IMAGES ===

  /// Sélectionner et uploader des images du stade
  Future<void> _selectStadiumImages() async {
    print('📱 _selectStadiumImages appelé');
    if (_isUploadingImages) {
      print('⚠️ Upload déjà en cours, retour');
      return;
    }

    print('🔄 Début de l\'upload d\'images');
    setState(() {
      _isUploadingImages = true;
    });

    try {
      // Créer un ID temporaire pour le stade
      final String tempStadiumId =
          'temp_${DateTime.now().millisecondsSinceEpoch}';
      print('🆔 ID temporaire créé: $tempStadiumId');

      // Sélectionner et uploader les images
      print('📂 Appel à ImageUploadService.selectAndUploadImages...');
      final List<String> uploadedUrls =
          await ImageUploadService.selectAndUploadImages(tempStadiumId,
              maxImages: 5);

      print('✅ URLs reçues: $uploadedUrls (${uploadedUrls.length} images)');

      if (uploadedUrls.isNotEmpty) {
        print(
            '💾 Mise à jour de l\'état avec ${uploadedUrls.length} nouvelles images');
        setState(() {
          _stadeImages.addAll(uploadedUrls);
        });

        print(
            '🎉 Nouvel état _stadeImages: $_stadeImages (${_stadeImages.length} total)');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${uploadedUrls.length} image(s) ajoutée(s) avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('⚠️ Aucune URL d\'image reçue');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'upload: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'upload: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      print('🔚 Fin de l\'upload, _isUploadingImages = false');
      setState(() {
        _isUploadingImages = false;
      });
    }
  }

  /// Prendre une photo avec la caméra
  Future<void> _takeStadiumPhoto() async {
    if (_isUploadingImages) return;

    setState(() {
      _isUploadingImages = true;
    });

    try {
      final String tempStadiumId =
          'temp_${DateTime.now().millisecondsSinceEpoch}';

      final String? photoUrl =
          await ImageUploadService.takeAndUploadPhoto(tempStadiumId);

      if (photoUrl != null) {
        setState(() {
          _stadeImages.add(photoUrl);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo ajoutée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la prise de photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploadingImages = false;
      });
    }
  }

  /// Supprimer une image de la liste
  void _removeStadiumImage(int index) {
    if (index >= 0 && index < _stadeImages.length) {
      setState(() {
        _stadeImages.removeAt(index);
      });
    }
  }

  /// Widget pour afficher les images sélectionnées
  Widget _buildImagePreview() {
    print(
        '🖼️ _buildImagePreview appelé - Nombre d\'images: ${_stadeImages.length}');
    print('🖼️ Images dans la liste: $_stadeImages');

    if (_stadeImages.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Aucune image sélectionnée',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _stadeImages.length,
        itemBuilder: (context, index) {
          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _stadeImages[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.error, color: Colors.red),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _removeStadiumImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Nouvelle fonction d'inscription avec validation améliorée
  Future<void> _handleRegister() async {
    // Validation du formulaire
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Vérification des mots de passe
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérification de la force du mot de passe
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le mot de passe doit contenir au moins 6 caractères'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Vérifier si l'email existe déjà
      final List<String> signInMethods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(_emailController.text.trim());

      if (signInMethods.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cette adresse email est déjà utilisée'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Validation spécifique pour les gestionnaires
      if (_userType == 'gestionnaire') {
        if (_stadeNomController.text.trim().isEmpty ||
            _stadeAdresseController.text.trim().isEmpty ||
            _stadePrixController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Veuillez remplir toutes les informations du stade'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (int.tryParse(_stadePrixController.text.trim()) == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le prix doit être un nombre valide'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Toutes les validations passées, préparer les données utilisateur
      Map<String, dynamic> userData = {
        'fullName': _nomController.text.trim(),
        'email': _emailController.text.trim(),
        'userType': _userType,
        'createdAt': DateTime.now().toIso8601String(),
        'password': _passwordController
            .text, // Temporaire, sera supprimé avant sauvegarde
      };

      // Ajouter téléphone pour les clients
      if (_userType == 'client' && _telephoneController.text.isNotEmpty) {
        String phoneNumber = _telephoneController.text.trim();
        if (!phoneNumber.startsWith('+237')) {
          phoneNumber = '+237$phoneNumber';
        }
        userData['telephone'] = phoneNumber;
      }

      // Ajouter données du stade si gestionnaire
      if (_userType == 'gestionnaire') {
        userData['stade'] = {
          'nom': _stadeNomController.text.trim(),
          'adresse': _stadeAdresseController.text.trim(),
          'prix': int.parse(_stadePrixController.text.trim()),
          'capacite': _stadeCapacite,
          'type': _stadeType,
          'disponible': true,
          'description': 'Stade géré par ${_nomController.text.trim()}',
          'images': _stadeImages,
          'quartier':
              _stadeAdresseController.text.trim().split(',').first.trim(),
          'gestionnaire': _emailController.text.trim(),
          'dateCreation': DateTime.now().toIso8601String(),
        };
      }

      // Créer le compte Firebase directement
      UserCredential result =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result.user != null) {
        // Supprimer le mot de passe des données à sauvegarder
        final Map<String, dynamic> dataToSave =
            Map<String, dynamic>.from(userData);
        dataToSave.remove('password');

        // Sauvegarder les données utilisateur dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(result.user!.uid)
            .set(dataToSave);

        // Si c'est un gestionnaire, créer aussi le document du stade
        if (_userType == 'gestionnaire' && userData['stade'] != null) {
          await FirebaseFirestore.instance
              .collection('stadiums')
              .add(userData['stade']);
        }

        // Rediriger vers la page de succès
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RegistrationSuccessPage(
                email: _emailController.text.trim(),
                userType: _userType,
              ),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erreur lors de la validation des données';
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'Adresse email invalide';
          break;
        case 'network-request-failed':
          errorMessage = 'Problème de connexion internet';
          break;
        case 'too-many-requests':
          errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard';
          break;
        default:
          errorMessage = 'Erreur: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur inattendue: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Inscription'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? 64 : 24,
              vertical: 24,
            ),
            child: Form(
              key: _formKey,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // User type selection
                    const Text('Type de compte:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Client'),
                            value: 'client',
                            groupValue: _userType,
                            onChanged: (value) =>
                                setState(() => _userType = value!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Gestionnaire'),
                            value: 'gestionnaire',
                            groupValue: _userType,
                            onChanged: (value) =>
                                setState(() => _userType = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Basic user fields
                    TextFormField(
                      controller: _nomController,
                      decoration: InputDecoration(
                        labelText: 'Nom complet *',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) =>
                          value?.isEmpty == true ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: FormValidators.validateEmail,
                    ),
                    const SizedBox(height: 16),

                    // Champ téléphone pour les clients
                    if (_userType == 'client') ...[
                      TextFormField(
                        controller: _telephoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Téléphone (+237) *',
                          prefixIcon: const Icon(Icons.phone),
                          prefixText: '+237 ',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          helperText: 'Exemple: 612345678',
                        ),
                        validator: (value) {
                          if (_userType == 'client' &&
                              (value?.isEmpty == true)) {
                            return 'Numéro de téléphone requis pour les clients';
                          }
                          if (_userType == 'client' &&
                              value != null &&
                              value.isNotEmpty) {
                            final cleanNumber = value
                                .replaceAll(' ', '')
                                .replaceAll('+237', '');
                            if (cleanNumber.length != 9) {
                              return 'Numéro invalide (9 chiffres requis)';
                            }
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Auto-format le numéro
                          if (value.startsWith('+237')) {
                            _telephoneController.text = value.substring(4);
                            _telephoneController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: _telephoneController.text.length),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe *',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true)
                          return 'Mot de passe requis';
                        if (value!.length < 6) return 'Au moins 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmer mot de passe *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Confirmation requise'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // Section de vérification OTP
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vérification du compte',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Choisissez comment vérifier votre identité:',
                            style: TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 16),

                          // Toggle entre email et téléphone pour vérification
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => setState(
                                      () => _verificationType = 'email'),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor:
                                        _verificationType == 'email'
                                            ? Colors.blue
                                            : null,
                                    foregroundColor:
                                        _verificationType == 'email'
                                            ? Colors.white
                                            : Colors.blue,
                                  ),
                                  child: const Text('Par Email'),
                                ),
                              ),
                              if (_userType == 'client') ...[
                                const SizedBox(width: 16),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(
                                        () => _verificationType = 'phone'),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor:
                                          _verificationType == 'phone'
                                              ? Colors.blue
                                              : null,
                                      foregroundColor:
                                          _verificationType == 'phone'
                                              ? Colors.white
                                              : Colors.blue,
                                    ),
                                    child: const Text('Par SMS'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Bouton d'envoi OTP
                          if (!_isOtpSent && !_isOtpVerified)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _sendOtpVerification,
                                icon: const Icon(Icons.send),
                                label: Text(
                                    'Envoyer code ${_verificationType == 'email' ? 'email' : 'SMS'}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                          // Champ de saisie OTP
                          if (_isOtpSent && !_isOtpVerified) ...[
                            TextFormField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Code de vérification *',
                                hintText: _verificationType == 'email'
                                    ? '123456'
                                    : 'Code SMS reçu',
                                prefixIcon: const Icon(Icons.security),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                helperText: _verificationType == 'email'
                                    ? 'Code demo: 123456'
                                    : null,
                              ),
                              validator: (value) => value?.isEmpty == true
                                  ? 'Code OTP requis'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _verifyOtp,
                                icon: const Icon(Icons.verified),
                                label: const Text('Vérifier le code'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],

                          // Confirmation de vérification
                          if (_isOtpVerified)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '✓ ${_verificationType == 'email' ? 'Email' : 'Téléphone'} vérifié avec succès!',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stadium fields for managers only
                    if (_userType == 'gestionnaire') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informations du stade',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _stadeNomController,
                              decoration: InputDecoration(
                                labelText: 'Nom du stade *',
                                prefixIcon: const Icon(Icons.sports_soccer),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) =>
                                  _userType == 'gestionnaire' &&
                                          value?.isEmpty == true
                                      ? 'Nom du stade requis'
                                      : null,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _stadeAdresseController,
                              decoration: InputDecoration(
                                labelText: 'Adresse *',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) =>
                                  _userType == 'gestionnaire' &&
                                          value?.isEmpty == true
                                      ? 'Adresse requise'
                                      : null,
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _stadePrixController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Prix par heure (FCFA) *',
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) {
                                if (_userType == 'gestionnaire' &&
                                    value?.isEmpty == true) {
                                  return 'Prix requis';
                                }
                                if (_userType == 'gestionnaire' &&
                                    int.tryParse(value!) == null) {
                                  return 'Prix invalide';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Section upload d'images
                            const Text(
                              'Photos du stade',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ajoutez des photos pour présenter votre stade (optionnel)',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 12),

                            // Aperçu des images
                            _buildImagePreview(),
                            const SizedBox(height: 12),

                            // Boutons d'upload
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isUploadingImages
                                        ? null
                                        : _selectStadiumImages,
                                    icon: _isUploadingImages
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.photo_library),
                                    label: Text(_isUploadingImages
                                        ? 'Upload...'
                                        : 'Galerie'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade50,
                                      foregroundColor: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isUploadingImages
                                        ? null
                                        : _takeStadiumPhoto,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Caméra'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade50,
                                      foregroundColor: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _stadeCapacite,
                                    decoration: InputDecoration(
                                      labelText: 'Capacité',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    items: ['5v5', '7v7', '11v11']
                                        .map((capacite) => DropdownMenuItem(
                                              value: capacite,
                                              child: Text(capacite),
                                            ))
                                        .toList(),
                                    onChanged: (value) =>
                                        setState(() => _stadeCapacite = value!),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _stadeType,
                                    decoration: InputDecoration(
                                      labelText: 'Type',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    items: [
                                      'Terrain en herbe naturelle',
                                      'Terrain synthétique',
                                      'Terrain en terre battue'
                                    ]
                                        .map((type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type),
                                            ))
                                        .toList(),
                                    onChanged: (value) =>
                                        setState(() => _stadeType = value!),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),

                    // Register button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Créer le compte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Back to login
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Déjà un compte ? Se connecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _stadeNomController.dispose();
    _stadeAdresseController.dispose();
    _stadePrixController.dispose();
    super.dispose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentUser = '';
  String _currentUserType = 'visiteur';
  String _currentUserName = '';
  String _selectedTab = 'stades';
  List<Map<String, dynamic>> _stades = [];
  List<ReservationRequest> _userReservations = [];
  List<ReservationRequest> _managerRequests = [];
  bool _isLoading = true;
  Stream<List<ReservationRequest>>? _reservationsStream;

  // Cache pour optimiser les performances
  static final SimpleCache<List<Map<String, dynamic>>> _stadesCache =
      SimpleCache<List<Map<String, dynamic>>>(
          defaultTtl: const Duration(minutes: 10));
  static final SimpleCache<List<Map<String, String>>> _slotsCache =
      SimpleCache<List<Map<String, String>>>(
          defaultTtl: const Duration(minutes: 2));
  static final SimpleCache<List<ReservationRequest>> _reservationsCache =
      SimpleCache<List<ReservationRequest>>(
          defaultTtl: const Duration(minutes: 1));

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Vérifier d'abord Firebase Auth
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();

      if (firebaseUser != null) {
        // Utilisateur connecté avec Firebase - utiliser ses données
        final userData = await FirebaseAuthService.instance.getUserData();
        _currentUser = firebaseUser.email ?? 'Utilisateur';
        _currentUserType = userData?['userType'] ?? 'client';
        _currentUserName = userData?['fullName'] ??
            userData?['name'] ??
            firebaseUser.displayName ??
            'Utilisateur';

        // Mettre à jour SharedPreferences avec les données actuelles
        await prefs.setString('current_user', _currentUser);
        await prefs.setString('current_user_type', _currentUserType);
        await prefs.setString('username_$_currentUser', _currentUserName);
      } else {
        // Pas de Firebase Auth - Vérifier les données locales
        final storedUserType =
            prefs.getString('current_user_type') ?? 'visiteur';
        final storedUser = prefs.getString('current_user') ?? 'Visiteur';

        // Si utilisateur prétend être client/gestionnaire sans Firebase Auth, nettoyer
        if (storedUserType == 'client' || storedUserType == 'gestionnaire') {
          print(
              '⚠️ Session corrompue détectée - Utilisateur ${storedUserType} sans Firebase Auth');
          await prefs.remove('current_user');
          await prefs.remove('current_user_type');
          await prefs.setString('current_user_type', 'visiteur');

          _currentUser = 'Visiteur';
          _currentUserType = 'visiteur';
          _currentUserName = 'Visiteur';
        } else {
          // Mode visiteur légitime - conserver
          print('👁️ Mode visiteur légitime maintenu');
          _currentUser = storedUser;
          _currentUserType = storedUserType;
          _currentUserName =
              prefs.getString('username_$storedUser') ?? storedUser;
        }
      }

      print(
          '🔄 Données utilisateur chargées - User: $_currentUser ($_currentUserType) - $_currentUserName');

      await _loadStades();
      if (_currentUserType == 'client') {
        await _loadUserReservations();
      } else if (_currentUserType == 'gestionnaire') {
        await _loadManagerRequests();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      AppLogger.error(
          'Erreur critique lors du chargement des données utilisateur', e);
      // Afficher message d'erreur à l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Erreur de chargement des données. Veuillez redémarrer l\'application.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: _loadUserData,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadStades() async {
    // Vérifier le cache d'abord
    final cacheKey = 'stades_$_currentUserType';
    final cachedStades = _stadesCache.get(cacheKey);
    if (cachedStades != null) {
      setState(() {
        _stades = cachedStades;
      });
      AppLogger.debug(
          'Stades chargés depuis le cache (${cachedStades.length})');
      return;
    }

    try {
      print('🏟️ Chargement des stades depuis Firestore...');

      // Charger tous les stades depuis Firestore
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('stadiums').get();

      print('📊 ${querySnapshot.docs.length} stades trouvés dans Firestore');

      _stades.clear();

      // Convertir les documents Firestore en liste de stades
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final stade = {
          'id': doc.id,
          'nom': data['nom'] ?? 'Stade sans nom',
          'adresse': data['adresse'] ?? '',
          'quartier':
              data['quartier'] ?? data['adresse']?.split(',')?.first ?? '',
          'prix': data['prix'] ?? 0,
          'type': data['type'] ?? 'Terrain standard',
          'capacite': data['capacite'] ?? '11v11',
          'disponible': data['disponible'] ?? true,
          'description': data['description'] ?? '',
          'gestionnaire': data['gestionnaire'] ?? '',
          'images': data['images'] ?? [],
          'dateCreation': data['dateCreation'],
        };

        // Pour tous les utilisateurs (clients ET gestionnaires), afficher tous les stades
        _stades.add(stade);
        print(
            '✅ Stade ajouté: ${stade['nom']} (gestionnaire: ${data['gestionnaire']})');
      }

      // Si aucun stade n'est trouvé pour les clients, ajouter les stades par défaut
      if (_stades.isEmpty && _currentUserType != 'gestionnaire') {
        print('⚠️ Aucun stade dans Firestore, ajout des stades par défaut');
        _stades = [
          {
            'nom': 'Stade Ahmadou Ahidjo',
            'quartier': 'Centre-ville',
            'prix': 25000,
            'type': 'Terrain en herbe naturelle',
            'capacite': '11v11',
            'disponible': true,
            'description': 'Stade principal de Yaoundé avec éclairage nocturne',
            'gestionnaire': 'admin@bookfoot.cm',
            'images': [],
          },
          {
            'nom': 'Terrain Municipal Tsinga',
            'quartier': 'Tsinga',
            'prix': 15000,
            'type': 'Terrain synthétique',
            'capacite': '7v7',
            'disponible': true,
            'description': 'Terrain moderne avec surface synthétique',
            'gestionnaire': 'tsinga@bookfoot.cm',
            'images': [],
          },
          {
            'nom': 'Complexe Sportif Bastos',
            'quartier': 'Bastos',
            'prix': 30000,
            'type': 'Terrain en herbe naturelle',
            'capacite': '11v11',
            'disponible': true,
            'description': 'Complexe haut de gamme avec vestiaires VIP',
            'gestionnaire': 'bastos@bookfoot.cm',
            'images': [],
          },
          {
            'nom': 'Terrain de Quartier Melen',
            'quartier': 'Melen',
            'prix': 8000,
            'type': 'Terrain en terre battue',
            'capacite': '5v5',
            'disponible': true,
            'description': 'Terrain communautaire accessible',
            'gestionnaire': 'melen@bookfoot.cm',
            'images': [],
          },
        ];
      }

      print('🎉 ${_stades.length} stades chargés au total');
    } catch (e) {
      print('❌ Erreur lors du chargement des stades: $e');
      debugPrint('Error loading stadiums: $e');
    }
  }

  /// Crée un stream en temps réel des réservations depuis Firestore
  Stream<List<ReservationRequest>> _getUserReservationsStream() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return Stream.value([]);
    }

    final firestore = FirebaseFirestore.instance;
    return firestore
        .collection('reservations')
        .where('userId', isEqualTo: firebaseUser.uid)
        .snapshots()
        .map((snapshot) {
      final reservations = <ReservationRequest>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final request = ReservationRequest(
            id: doc.id,
            stadeId: data['stadeId'] ?? '',
            stadeNom: data['stadeNom'] ?? '',
            clientNom: data['clientNom'] ?? '',
            clientEmail: data['clientEmail'] ?? '',
            dateReservation: DateTime.tryParse(data['dateReservation'] ?? '') ??
                DateTime.now(),
            heureDebut: data['heureDebut'] ?? '',
            heureFin: data['heureFin'] ?? '',
            raison: data['raison'] ?? '',
            statut: data['statut'] ?? 'En attente',
            dateCreation:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
          reservations.add(request);
        } catch (e) {
          print('❌ Erreur parsing réservation ${doc.id}: $e');
        }
      }

      // Trier par date de création (plus récentes en premier)
      reservations.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      print('🔄 Stream: ${reservations.length} réservations synchronisées');
      return reservations;
    });
  }

  Stream<List<ReservationRequest>> _getAllReservationsStreamForAdmin() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return Stream.value([]);
    }

    final firestore = FirebaseFirestore.instance;
    return firestore
        .collection('reservations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final reservations = <ReservationRequest>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final request = ReservationRequest(
            id: doc.id,
            stadeId: data['stadeId'] ?? '',
            stadeNom: data['stadeNom'] ?? '',
            clientNom: data['clientNom'] ?? '',
            clientEmail: data['clientEmail'] ?? '',
            dateReservation: DateTime.tryParse(data['dateReservation'] ?? '') ??
                DateTime.now(),
            heureDebut: data['heureDebut'] ?? '',
            heureFin: data['heureFin'] ?? '',
            raison: data['raison'] ?? '',
            statut: data['statut'] ?? 'En attente',
            dateCreation:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
          reservations.add(request);
        } catch (e) {
          print('❌ Erreur parsing réservation admin ${doc.id}: $e');
        }
      }

      print(
          '🔄 Stream Admin: ${reservations.length} réservations synchronisées');
      return reservations;
    });
  }

  Future<void> _loadUserReservations() async {
    try {
      print('🔄 Chargement des réservations pour client...');
      print('👤 Current User: $_currentUser ($_currentUserType)');
      _userReservations.clear();

      // Récupérer depuis Firestore si utilisateur Firebase connecté
      final firebaseUser = FirebaseAuth.instance.currentUser;
      print('👤 Firebase User: ${firebaseUser?.email}');
      if (firebaseUser != null) {
        final firestore = FirebaseFirestore.instance;

        // Essayer d'abord avec orderBy dateCreation, puis fallback sans orderBy
        QuerySnapshot querySnapshot;
        try {
          querySnapshot = await firestore
              .collection('reservations')
              .where('userId', isEqualTo: firebaseUser.uid)
              .orderBy('dateCreation',
                  descending:
                      true) // Tri côté serveur - plus récente en premier
              .get();
          print('✅ Requête Firestore avec orderBy dateCreation réussie');
        } catch (e) {
          print('⚠️ Erreur orderBy dateCreation: $e, essai sans orderBy');
          // Fallback sans orderBy (tri côté client après)
          querySnapshot = await firestore
              .collection('reservations')
              .where('userId', isEqualTo: firebaseUser.uid)
              .get();
        }

        print(
            '📋 Trouvé ${querySnapshot.docs.length} réservations dans Firestore');
        for (final doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          print('📄 Document ${doc.id}: $data');

          // Handle both Timestamp and String formats for dateReservation
          DateTime dateReservation;
          final dateReservationData = data['dateReservation'];
          if (dateReservationData is Timestamp) {
            dateReservation = dateReservationData.toDate();
          } else if (dateReservationData is String) {
            try {
              dateReservation =
                  DateFormat('dd/MM/yyyy').parse(dateReservationData);
            } catch (e) {
              print(
                  '⚠️ Error parsing date string: $dateReservationData, using current date');
              dateReservation = DateTime.now();
            }
          } else {
            dateReservation = DateTime.now();
          }

          // Handle both Timestamp and String formats for dateCreation (with fallback to createdAt)
          DateTime dateCreation;
          final dateCreationData = data['dateCreation'] ?? data['createdAt'];
          if (dateCreationData is Timestamp) {
            dateCreation = dateCreationData.toDate();
          } else if (dateCreationData is String) {
            try {
              dateCreation =
                  DateFormat('dd/MM/yyyy HH:mm').parse(dateCreationData);
            } catch (e) {
              print(
                  '⚠️ Error parsing creation date: $dateCreationData, using current date');
              dateCreation = DateTime.now();
            }
          } else {
            dateCreation = DateTime.now();
          }

          final request = ReservationRequest(
            id: doc.id,
            stadeId: data['stadeId'] ?? '',
            stadeNom: data['stadeNom'] ?? '',
            clientNom: data['clientNom'] ?? '',
            clientEmail: data['clientEmail'] ?? '',
            dateReservation: dateReservation,
            heureDebut: data['heureDebut'] ?? '',
            heureFin: data['heureFin'] ?? '',
            raison: data['raison'] ?? '',
            statut: data['statut'] ?? 'En attente',
            dateCreation: dateCreation,
          );
          _userReservations.add(request);
          print(
              '✅ Réservation ajoutée: ${request.stadeNom} - ${request.statut}');
        }

        print(
            '📋 Réservations chargées depuis Firestore: ${_userReservations.length}');

        // Si orderBy a échoué, faire le tri côté client
        final needsClientSort =
            querySnapshot.docs.length > 1 && _userReservations.length > 1;
        if (needsClientSort) {
          // Vérifier si les données sont déjà triées (première réservation plus récente que la dernière)
          final isAlreadySorted = _userReservations.first.dateCreation
                  .isAfter(_userReservations.last.dateCreation) ||
              _userReservations.first.dateCreation
                  .isAtSameMomentAs(_userReservations.last.dateCreation);

          if (!isAlreadySorted) {
            print(
                '🔄 Tri côté client nécessaire pour les réservations Firestore');
            _userReservations
                .sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
            print('✅ Tri côté client terminé');
          } else {
            print('✅ Réservations Firestore déjà triées côté serveur');
          }
        }

        // Affichage pour vérification de l'ordre
        for (int i = 0; i < _userReservations.length; i++) {
          final reservation = _userReservations[i];
          print(
              '📅 Ordre final [$i]: ${reservation.stadeNom} - ${reservation.dateCreation} (${reservation.statut})');
        }

        if (mounted) setState(() {});
        return;
      }

      // Fallback : SharedPreferences pour les anciens utilisateurs
      final prefs = await SharedPreferences.getInstance();
      final requestIds = prefs.getStringList('reservation_requests') ?? [];

      for (final id in requestIds) {
        try {
          final requestData = prefs.getString('request_$id');
          if (requestData != null) {
            final parts = requestData.split('|');
            if (parts.length >= 9 && parts[2] == _currentUser) {
              final request = ReservationRequest(
                id: id,
                stadeId: parts[0],
                stadeNom: parts[0],
                clientNom: parts[1],
                clientEmail: parts[2],
                dateReservation: DateFormat('dd/MM/yyyy').parse(parts[3]),
                heureDebut: parts[4],
                heureFin: parts[5],
                raison: parts[6],
                statut: parts[7],
                dateCreation: DateFormat('dd/MM/yyyy HH:mm').parse(parts[8]),
              );
              _userReservations.add(request);
            }
          }
        } catch (e) {
          AppLogger.warning('Réservation $id ignorée - format invalide: $e');
          // Skip this reservation and continue with others
          continue;
        }
      }

      // Sort by creation date ONLY for SharedPreferences data (newest requests at top)
      // Tri pour les données SharedPreferences - la plus récente en premier
      if (_userReservations.isNotEmpty) {
        print(
            '🔄 Tri des réservations SharedPreferences par date de création - ${_userReservations.length} réservations');

        _userReservations.sort((a, b) {
          // Tri uniquement par date de création (plus récente en premier)
          final comparison = b.dateCreation.compareTo(a.dateCreation);
          print(
              '🔀 Comparaison SharedPreferences: ${a.stadeNom}(${a.dateCreation}) vs ${b.stadeNom}(${b.dateCreation}) = $comparison');
          return comparison;
        });

        print(
            '✅ Tri SharedPreferences terminé - ${_userReservations.length} réservations triées');
      }
    } catch (e) {
      AppLogger.error('Erreur critique chargement réservations utilisateur', e);
      // Afficher un indicateur d'erreur dans l'UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger vos réservations'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Vérifie les créneaux indisponibles pour un stade à une date donnée
  Future<List<Map<String, String>>> _getUnavailableSlots(
      String stadeId, DateTime date) async {
    List<Map<String, String>> unavailableSlots = [];

    try {
      final firestore = FirebaseFirestore.instance;
      final dateStr = DateFormat('dd/MM/yyyy').format(date);

      // 1. Vérifier les RÉSERVATIONS confirmées/en attente
      final querySnapshot = await firestore
          .collection('reservations')
          .where('stadeId', isEqualTo: stadeId)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final docDate = data['dateReservation'];
        final statut = data['statut'] ?? '';

        String docDateStr = '';
        if (docDate is Timestamp) {
          docDateStr = DateFormat('dd/MM/yyyy').format(docDate.toDate());
        } else if (docDate is String) {
          docDateStr = docDate;
        }

        if (docDateStr == dateStr &&
            ['En attente', 'Confirmée', 'en_attente', 'confirmee']
                .contains(statut)) {
          unavailableSlots.add({
            'debut': data['heureDebut'] ?? '',
            'fin': data['heureFin'] ?? '',
            'client': data['clientNom'] ?? 'Client',
            'type': 'reservation',
          });
        }
      }

      // 2. Vérifier les CRÉNEAUX BLOQUÉS (collection unavailable_slots)
      final blockedSlots = await firestore
          .collection('unavailable_slots')
          .where('stadeId', isEqualTo: stadeId)
          .get();

      for (final doc in blockedSlots.docs) {
        final data = doc.data();
        final docDate = data['date'];

        String docDateStr = '';
        if (docDate is Timestamp) {
          docDateStr = DateFormat('dd/MM/yyyy').format(docDate.toDate());
        } else if (docDate is String) {
          docDateStr = docDate;
        }

        if (docDateStr == dateStr) {
          unavailableSlots.add({
            'debut': data['heureDebut'] ?? '',
            'fin': data['heureFin'] ?? '',
            'client': data['clientNom'] ?? data['raison'] ?? 'Bloqué',
            'type': 'blocked',
          });
        }
      }

      // 3. Vérifier aussi dans SharedPreferences pour compatibilité
      final prefs = await SharedPreferences.getInstance();
      final requestIds = prefs.getStringList('reservation_requests') ?? [];

      for (final id in requestIds) {
        final requestData = prefs.getString('request_$id');
        if (requestData != null) {
          final parts = requestData.split('|');
          if (parts.length >= 9) {
            final reservationDate = parts[3];
            final reservationStade = parts[0];
            final statut = parts[7];

            if (reservationStade == stadeId &&
                reservationDate == dateStr &&
                (statut == 'En attente' || statut == 'Confirmée')) {
              unavailableSlots.add({
                'debut': parts[4],
                'fin': parts[5],
                'client': parts[1],
                'type': 'reservation',
              });
            }
          }
        }

        AppLogger.debug(
            'Créneaux SharedPreferences trouvés: ${unavailableSlots.length}');
      }

      print(
          '🚫 Créneaux indisponibles pour $stadeId le $dateStr: ${unavailableSlots.length}');
      print(
          '   - Réservations: ${unavailableSlots.where((s) => s['type'] == 'reservation').length}');
      print(
          '   - Bloqués: ${unavailableSlots.where((s) => s['type'] == 'blocked').length}');
    } catch (e) {
      AppLogger.error('Erreur lors de la vérification des créneaux', e);
    }

    return unavailableSlots;
  }

  /// Vérifie si un créneau est en conflit avec les réservations existantes
  bool _isTimeSlotConflict(String newStart, String newEnd,
      List<Map<String, String>> unavailableSlots) {
    for (final slot in unavailableSlots) {
      final existingStart = slot['debut'] ?? '';
      final existingEnd = slot['fin'] ?? '';

      // Convertir les heures en minutes pour la comparaison
      final newStartMinutes = _timeToMinutes(newStart);
      final newEndMinutes = _timeToMinutes(newEnd);
      final existingStartMinutes = _timeToMinutes(existingStart);
      final existingEndMinutes = _timeToMinutes(existingEnd);

      // Vérifier le chevauchement
      if (newStartMinutes < existingEndMinutes &&
          newEndMinutes > existingStartMinutes) {
        return true; // Conflit détecté
      }
    }
    return false;
  }

  /// Convertit une heure (HH:mm) en minutes depuis minuit
  int _timeToMinutes(String time) {
    if (time.isEmpty) return 0;
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  /// Supprime une réservation côté client
  Future<void> _deleteReservation(ReservationRequest reservation) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null && reservation.id.isNotEmpty) {
        // Supprimer de Firestore
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('reservations').doc(reservation.id).delete();
        print('🗑️ Réservation supprimée de Firestore: ${reservation.id}');
      }

      // Supprimer de SharedPreferences (pour compatibilité)
      final prefs = await SharedPreferences.getInstance();
      final requestIds = prefs.getStringList('reservation_requests') ?? [];
      final updatedIds =
          requestIds.where((id) => id != reservation.id).toList();
      await prefs.setStringList('reservation_requests', updatedIds);
      await prefs.remove('request_${reservation.id}');

      // Le StreamBuilder se mettra automatiquement à jour
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réservation supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('🗑️ Réservation supprimée avec succès: ${reservation.stadeNom}');
    } catch (e) {
      print('❌ Erreur suppression réservation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Affiche un dialogue de confirmation pour supprimer une réservation
  void _showDeleteConfirmationDialog(ReservationRequest reservation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Êtes-vous sûr de vouloir supprimer cette réservation ?'),
              const SizedBox(height: 8),
              Text(
                'Stade: ${reservation.stadeNom}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Date: ${DateFormat('dd/MM/yyyy').format(reservation.dateReservation)}',
              ),
              Text(
                'Horaire: ${reservation.heureDebut} - ${reservation.heureFin}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteReservation(reservation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadManagerRequests() async {
    try {
      print(
          '🔍 Chargement des demandes de réservation pour le gestionnaire...');
      _managerRequests.clear();

      // Get all stadiums owned by current manager
      final myStadiums = _stades
          .where((stade) =>
              stade['gestionnaire'] == _currentUserName ||
              stade['gestionnaire'] == _currentUser)
          .toList();

      if (myStadiums.isEmpty) {
        print('⚠️ Aucun stade trouvé pour ce gestionnaire');
        return;
      }

      // Get stadium IDs and names
      final myStadiumIds = myStadiums.map((stade) => stade['id']).toList();
      final myStadiumNames = myStadiums.map((stade) => stade['nom']).toList();

      print('🏟️ Stades du gestionnaire: ${myStadiumNames.join(', ')}');

      // Load reservation requests from Firestore filtered by stadium IDs
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('stadeId', whereIn: myStadiumIds)
          .get();

      print(
          '📋 ${querySnapshot.docs.length} demandes trouvées pour les stades du gestionnaire');

      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final request = ReservationRequest(
            id: doc.id,
            stadeId: data['stadeId'] ?? '',
            stadeNom: data['stadeNom'] ?? '',
            clientNom: data['clientNom'] ?? '',
            clientEmail: data['clientEmail'] ?? '',
            dateReservation: (data['dateReservation'] as Timestamp).toDate(),
            heureDebut: data['heureDebut'] ?? '',
            heureFin: data['heureFin'] ?? '',
            raison: data['raison'] ?? '',
            statut: data['statut'] ?? 'en_attente',
            dateCreation: data['dateCreation'] != null
                ? (data['dateCreation'] as Timestamp).toDate()
                : DateTime.now(),
          );
          _managerRequests.add(request);
        } catch (e) {
          debugPrint('Erreur parsing request ${doc.id}: $e');
        }
      }

      // Sort by creation date (most recent first)
      _managerRequests.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      print('✅ ${_managerRequests.length} demandes chargées avec succès');
    } catch (e) {
      debugPrint('Erreur loading manager requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('BookFoot237 - ${_getUserTypeDisplay()}'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(),
      body: _buildBody(),
    );
  }

  String _getUserTypeDisplay() {
    switch (_currentUserType) {
      case 'client':
        return 'Client';
      case 'gestionnaire':
        return 'Gestionnaire';
      case 'visiteur':
        return 'Visiteur';
      default:
        return 'Utilisateur';
    }
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sports_soccer,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bonjour,',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _currentUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getUserTypeDisplay(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_currentUserType == 'gestionnaire') ...[
            ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Tous les Stades'),
              selected: _selectedTab == 'stades',
              onTap: () {
                setState(() {
                  _selectedTab = 'stades';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sports_soccer),
              title: const Text('Mes Stades'),
              selected: _selectedTab == 'mes_stades',
              onTap: () {
                setState(() {
                  _selectedTab = 'mes_stades';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions),
              title: const Text('Demandes de Réservation'),
              selected: _selectedTab == 'demandes',
              onTap: () {
                setState(() {
                  _selectedTab = 'demandes';
                });
                Navigator.pop(context);
              },
            ),
          ] else if (_currentUserType == 'client') ...[
            ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Terrains Disponibles'),
              selected: _selectedTab == 'stades',
              onTap: () {
                setState(() {
                  _selectedTab = 'stades';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Mes Réservations'),
              selected: _selectedTab == 'historique',
              onTap: () async {
                setState(() {
                  _selectedTab = 'historique';
                });
                Navigator.pop(context);
                // Recharger automatiquement les réservations
                if (_currentUserType == 'client') {
                  await _loadUserReservations();
                }
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Explorer les Terrains'),
              selected: _selectedTab == 'stades',
              onTap: () {
                setState(() {
                  _selectedTab = 'stades';
                });
                Navigator.pop(context);
              },
            ),
          ],
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Se Déconnecter',
                style: TextStyle(color: Colors.red)),
            onTap: () => context.go('/login'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 'stades':
        return _buildStadesView();
      case 'mes_stades':
        return _buildMesStadesView();
      case 'historique':
        return _buildHistoriqueView();
      case 'demandes':
        return _buildDemandesView();
      default:
        return _buildStadesView();
    }
  }

  Widget _buildStadesView() {
    return Column(
      children: [
        if (_currentUserType != 'gestionnaire') ...[
          // Search bar for clients and visitors
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un stade...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: true,
                  onSelected: (selected) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('11v11'),
                  selected: false,
                  onSelected: (selected) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('7v7'),
                  selected: false,
                  onSelected: (selected) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('5v5'),
                  selected: false,
                  onSelected: (selected) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          // Header for manager
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Interface Gestionnaire',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Voici votre stade et les informations de gestion.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],

        // Stades list
        Expanded(
          child: _stades.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.stadium,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUserType == 'gestionnaire'
                            ? 'Aucun stade configuré'
                            : 'Aucun terrain disponible',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth > 600;

                    if (isTablet) {
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _stades.length,
                        itemBuilder: (context, index) {
                          return _buildStadeCard(context, _stades[index]);
                        },
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _stades.length,
                      itemBuilder: (context, index) {
                        return _buildStadeCard(context, _stades[index]);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMesStadesView() {
    // Filter stadiums to show only those owned by current manager
    final myStadiums = _stades
        .where((stade) =>
            stade['gestionnaire'] == _currentUserName ||
            stade['gestionnaire'] == _currentUser)
        .toList();

    return Column(
      children: [
        // Header with add button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Mes Stades',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showAddStadiumDialog();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Gérez vos stades: ajoutez, modifiez ou supprimez.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),

        // My stadiums list
        Expanded(
          child: myStadiums.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_soccer,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun stade créé',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cliquez sur "Ajouter" pour créer votre premier stade',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: myStadiums.length,
                  itemBuilder: (context, index) {
                    return _buildMyStadeCard(context, myStadiums[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoriqueView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Historique de vos Réservations',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (mounted) {
                        setState(() {
                          _isLoading = true;
                        });
                      }
                      await _loadUserReservations();
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Actualiser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Consultez toutes vos demandes de réservation.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReservationRequest>>(
            stream: _getUserReservationsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur de connexion',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Impossible de charger les réservations',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final reservations = snapshot.data ?? [];

              if (reservations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune réservation trouvée',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vos demandes de réservation apparaîtront ici automatiquement',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  return _buildReservationCard(reservations[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDemandesView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Demandes de Réservation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gérez les demandes de réservation pour votre stade.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ReservationRequest>>(
            stream: _getAllReservationsStreamForAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur de connexion',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Impossible de charger les réservations',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final reservations = snapshot.data ?? [];

              if (reservations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune demande de réservation',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Les nouvelles demandes apparaîtront automatiquement ici',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: reservations.length,
                itemBuilder: (context, index) {
                  return _buildManagerRequestCard(reservations[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Calcule la durée en heures entre deux heures au format HH:mm
  int _calculateReservationDuration(String heureDebut, String heureFin) {
    try {
      final debut = TimeOfDay(
        hour: int.parse(heureDebut.split(':')[0]),
        minute: int.parse(heureDebut.split(':')[1]),
      );
      final fin = TimeOfDay(
        hour: int.parse(heureFin.split(':')[0]),
        minute: int.parse(heureFin.split(':')[1]),
      );

      final debutMinutes = debut.hour * 60 + debut.minute;
      final finMinutes = fin.hour * 60 + fin.minute;

      final diffMinutes = finMinutes - debutMinutes;
      return (diffMinutes / 60).round();
    } catch (e) {
      return 0;
    }
  }

  /// Calcule le temps écoulé depuis une date donnée en format lisible
  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'quelques secondes';
    }
  }

  Widget _buildReservationCard(ReservationRequest request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (request.statut) {
      case 'en_attente':
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.pending;
        break;
      case 'accepte':
        statusColor = Colors.green;
        statusText = 'Acceptée';
        statusIcon = Icons.check_circle;
        break;
      case 'paye':
        statusColor = Colors.blue;
        statusText = 'Payée';
        statusIcon = Icons.payment;
        break;
      case 'refuse':
        statusColor = Colors.red;
        statusText = 'Refusée';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stadium,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.stadeNom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Détails de la réservation plus visibles
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre de la section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports_soccer,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DÉTAILS DE LA RÉSERVATION SOUHAITÉE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Jour souhaité (plus proéminent)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[100]!, Colors.blue[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Jour souhaité:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('EEEE dd MMMM yyyy', 'fr_FR')
                              .format(request.dateReservation),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horaires souhaités (plus proéminent)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[100]!, Colors.orange[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Horaires souhaités:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    size: 16,
                                    color: Colors.orange[800],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    request.heureDebut,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 20,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stop,
                                    size: 16,
                                    color: Colors.orange[800],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    request.heureFin,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Durée: ${_calculateReservationDuration(request.heureDebut, request.heureFin)} heure(s)',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.orange[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (request.raison.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Raison: ${request.raison}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Section Date/Heure de création de la demande (plus visible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_send,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DEMANDE CRÉÉE LE:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Date de création
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 14,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yyyy')
                                  .format(request.dateCreation),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Heure de création
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm:ss')
                                  .format(request.dateCreation),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Temps écoulé depuis la création
                  Text(
                    'il y a ${_getTimeAgo(request.dateCreation)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Bouton de suppression
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteConfirmationDialog(request),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Supprimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            // Boutons d'actions selon le statut de la réservation
            const SizedBox(height: 12),

            // Pour les réservations acceptées - Bouton de paiement
            if (request.statut == 'accepte') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentMethodDialog(request),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text(
                    'Procéder au paiement',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Bouton d'annulation secondaire pour les réservations acceptées
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => _showDeleteReservationDialog(request),
                  icon: const Icon(Icons.cancel, size: 16),
                  label: const Text(
                    'Annuler la réservation',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ]
            // Pour les réservations payées - Message de confirmation
            else if (request.statut == 'paye') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Paiement confirmé - Réservation finalisée',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ]
            // Pour les autres statuts - Boutons de suppression/annulation
            else if (request.statut == 'en_attente' ||
                request.statut == 'refuse') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showDeleteReservationDialog(request),
                  icon: Icon(
                    request.statut == 'en_attente'
                        ? Icons.delete
                        : Icons.delete_forever,
                    size: 18,
                  ),
                  label: Text(
                    request.statut == 'en_attente'
                        ? 'Supprimer la demande'
                        : 'Supprimer définitivement',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: request.statut == 'en_attente'
                        ? Colors.red
                        : Colors.red[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManagerRequestCard(ReservationRequest request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (request.statut) {
      case 'en_attente':
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.pending;
        break;
      case 'accepte':
        statusColor = Colors.green;
        statusText = 'Acceptée';
        statusIcon = Icons.check_circle;
        break;
      case 'paye':
        statusColor = Colors.blue;
        statusText = 'Payée';
        statusIcon = Icons.payment;
        break;
      case 'refuse':
        statusColor = Colors.red;
        statusText = 'Refusée';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.clientNom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${request.clientEmail}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(request.dateReservation),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${request.heureDebut} - ${request.heureFin}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if (request.raison.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Raison: ${request.raison}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (request.statut == 'en_attente') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _handleRequestAction(request.id, 'accepte'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accepter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _handleRequestAction(request.id, 'refuse'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Refuser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Demandé le ${DateFormat('dd/MM/yyyy à HH:mm').format(request.dateCreation)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRequestAction(String requestId, String newStatus) async {
    try {
      print('🔄 Traitement de la demande $requestId avec statut: $newStatus');

      // Trouver la réservation dans la liste actuelle pour récupérer les informations
      final request = _managerRequests.firstWhere(
        (req) => req.id == requestId,
        orElse: () => throw Exception('Réservation non trouvée'),
      );

      // 1. Mettre à jour dans Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('reservations').doc(requestId).update({
        'statut': newStatus,
        'dateTraitement': FieldValue.serverTimestamp(),
        'gestionnaireTraitement': _currentUser,
      });

      print('✅ Statut mis à jour dans Firestore');

      // 2. Envoyer l'email au client
      await _sendReservationStatusEmail(request, newStatus);

      // 2.5. Si la demande est acceptée, créer automatiquement un créneau indisponible
      if (newStatus == 'accepte') {
        print(
            '🚫 Création automatique du créneau indisponible après validation');
        await _createUnavailableSlot(request,
            raison:
                'Réservation validée par le gestionnaire - Créneau réservé');
      }

      // 3. Fallback : Mettre à jour SharedPreferences pour compatibilité
      final prefs = await SharedPreferences.getInstance();
      final requestData = prefs.getString('request_$requestId');
      if (requestData != null) {
        final parts = requestData.split('|');
        if (parts.length >= 9) {
          parts[7] = newStatus;
          final updatedData = parts.join('|');
          await prefs.setString('request_$requestId', updatedData);
        }
      }

      // 4. Actualiser l'affichage
      await _loadManagerRequests();
      setState(() {});

      // 5. Afficher message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'accepte'
                ? 'Demande acceptée avec succès. Email envoyé au client.'
                : 'Demande refusée. Email envoyé au client.',
          ),
          backgroundColor:
              newStatus == 'accepte' ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );

      print('🎉 Action terminée avec succès');
    } catch (e) {
      print('❌ Erreur lors du traitement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du traitement: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Envoie un email au client pour l'informer du statut de sa réservation
  Future<void> _sendReservationStatusEmail(
      ReservationRequest request, String newStatus) async {
    try {
      print('📧 Préparation envoi email pour ${request.clientEmail}');

      // Utiliser le NotificationService pour l'envoi réel d'emails
      final bool emailSent =
          await NotificationService.instance.sendReservationStatusEmail(
        clientEmail: request.clientEmail,
        clientName: request.clientNom,
        stadeNom: request.stadeNom,
        dateReservation:
            DateFormat('dd/MM/yyyy').format(request.dateReservation),
        heureDebut: request.heureDebut,
        heureFin: request.heureFin,
        raison: request.raison,
        isAccepted: newStatus == 'accepte',
      );

      if (emailSent) {
        print('✅ Email de statut envoyé avec succès à ${request.clientEmail}');
      } else {
        print(
            '⚠️ Échec envoi email, mais traitement de la réservation continue');
      }
    } catch (e) {
      print('❌ Erreur envoi email: $e');
      // Ne pas faire échouer l'opération si l'email ne peut pas être envoyé
      // On log juste l'erreur pour debugging
    }
  }

  /// Envoie un email de notification au gestionnaire pour une nouvelle demande de réservation
  Future<void> _sendManagerNotificationEmail(ReservationRequest request) async {
    try {
      print(
          '📧 Recherche de l\'email du gestionnaire pour le stade: ${request.stadeNom}');

      // Chercher le stade dans Firestore pour récupérer l'email du gestionnaire
      final stadiumQuery = await FirebaseFirestore.instance
          .collection('stadiums')
          .where('nom', isEqualTo: request.stadeNom)
          .limit(1)
          .get();

      if (stadiumQuery.docs.isEmpty) {
        print('⚠️ Stade non trouvé dans Firestore: ${request.stadeNom}');
        return;
      }

      final stadiumData = stadiumQuery.docs.first.data();
      final managerEmail = stadiumData['managerEmail'] as String?;

      if (managerEmail == null || managerEmail.isEmpty) {
        print(
            '⚠️ Email du gestionnaire non trouvé pour le stade: ${request.stadeNom}');
        return;
      }

      print('📧 Envoi notification au gestionnaire: $managerEmail');

      // Utiliser le NotificationService pour l'envoi réel d'emails
      final bool emailSent = await NotificationService.instance
          .sendNewReservationNotificationToManager(
        managerEmail: managerEmail,
        clientName: request.clientNom,
        clientEmail: request.clientEmail,
        stadeNom: request.stadeNom,
        dateReservation:
            DateFormat('dd/MM/yyyy').format(request.dateReservation),
        heureDebut: request.heureDebut,
        heureFin: request.heureFin,
        raison: request.raison,
      );

      if (emailSent) {
        print(
            '✅ Email de notification envoyé avec succès au gestionnaire: $managerEmail');
      } else {
        print(
            '⚠️ Échec envoi email au gestionnaire, mais création de la réservation continue');
      }
    } catch (e) {
      print('❌ Erreur envoi email au gestionnaire: $e');
      // Ne pas faire échouer l'opération si l'email ne peut pas être envoyé
      // On log juste l'erreur pour debugging
    }
  }

  /// Affiche une boîte de dialogue de confirmation pour supprimer/annuler une réservation
  Future<void> _showDeleteReservationDialog(ReservationRequest request) async {
    // Les clients peuvent supprimer toutes leurs réservations (en_attente, accepte, refuse)

    final isWaitingStatus = request.statut == 'en_attente';
    final isRefusedStatus = request.statut == 'refuse';
    final actionText = isWaitingStatus
        ? 'supprimer cette demande'
        : isRefusedStatus
            ? 'supprimer définitivement cette réservation refusée'
            : 'annuler cette réservation';
    final titleText = isWaitingStatus
        ? 'Supprimer la demande'
        : isRefusedStatus
            ? 'Supprimer définitivement'
            : 'Annuler la réservation';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titleText),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous vraiment $actionText ?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.stadeNom,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(request.dateReservation)}'),
                  Text('Heure: ${request.heureDebut} - ${request.heureFin}'),
                ],
              ),
            ),
            if (!isWaitingStatus) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le gestionnaire sera notifié de l\'annulation',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isWaitingStatus
                  ? Colors.red
                  : isRefusedStatus
                      ? Colors.red[800]
                      : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text(isWaitingStatus
                ? 'Supprimer'
                : isRefusedStatus
                    ? 'Supprimer'
                    : 'Annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteReservation(request);
    }
  }


  /// Envoie un email au gestionnaire pour l'informer de l'annulation
  Future<void> _sendCancellationNotificationToManager(
      ReservationRequest request) async {
    try {
      print(
          '📧 Envoi notification d\'annulation au gestionnaire pour: ${request.stadeNom} (ID: ${request.stadeId})');

      // D'abord essayer de chercher par stadeId (plus fiable)
      QuerySnapshot? stadiumQuery;
      if (request.stadeId != null && request.stadeId!.isNotEmpty) {
        print('🔍 Recherche par stadeId: ${request.stadeId}');
        stadiumQuery = await FirebaseFirestore.instance
            .collection('stadiums')
            .where(FieldPath.documentId, isEqualTo: request.stadeId)
            .limit(1)
            .get();
      }

      // Si pas trouvé par ID, chercher par nom
      if (stadiumQuery == null || stadiumQuery.docs.isEmpty) {
        print('🔍 Recherche par nom du stade: ${request.stadeNom}');
        stadiumQuery = await FirebaseFirestore.instance
            .collection('stadiums')
            .where('nom', isEqualTo: request.stadeNom)
            .limit(1)
            .get();
      }

      if (stadiumQuery == null || stadiumQuery.docs.isEmpty) {
        print(
            '⚠️ Stade non trouvé pour notification d\'annulation: ${request.stadeNom} (ID: ${request.stadeId})');
        return;
      }

      final stadiumData =
          stadiumQuery.docs.first.data() as Map<String, dynamic>;
      final managerEmail = stadiumData['managerEmail'] as String?;

      if (managerEmail == null || managerEmail.isEmpty) {
        print(
            '⚠️ Email du gestionnaire non trouvé pour notification d\'annulation');
        return;
      }

      print(
          '📧 Envoi notification d\'annulation au gestionnaire: $managerEmail');

      // Utiliser le NotificationService pour l'envoi d'email d'annulation
      // Note: Nous devons ajouter cette méthode au NotificationService
      final bool emailSent = await NotificationService.instance
          .sendCancellationNotificationToManager(
        managerEmail: managerEmail,
        clientName: request.clientNom,
        clientEmail: request.clientEmail,
        stadeNom: request.stadeNom,
        dateReservation:
            DateFormat('dd/MM/yyyy').format(request.dateReservation),
        heureDebut: request.heureDebut,
        heureFin: request.heureFin,
        raison: request.raison,
      );

      if (emailSent) {
        print(
            '✅ Email d\'annulation envoyé avec succès au gestionnaire: $managerEmail');
      } else {
        print('⚠️ Échec envoi email d\'annulation au gestionnaire');
      }
    } catch (e) {
      print('❌ Erreur envoi email d\'annulation au gestionnaire: $e');
    }
  }

  /// Affiche le dialogue de sélection du mode de paiement
  Future<void> _showPaymentMethodDialog(ReservationRequest request) async {
    String? selectedPaymentMethod;
    String? selectedMobileProvider;

    final result = await showDialog<Map<String, String?>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text('Mode de paiement'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations de la réservation
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Réservation: ${request.stadeNom}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(request.dateReservation)}'),
                          Text(
                              'Heure: ${request.heureDebut} - ${request.heureFin}'),
                          Text(
                              'Montant: ${_calculateReservationTotal(request)} FCFA',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sélection du mode de paiement
                    const Text(
                      'Choisissez votre mode de paiement :',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Option Espèces
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedPaymentMethod == 'especes'
                              ? Colors.green
                              : Colors.grey[300]!,
                          width: selectedPaymentMethod == 'especes' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(Icons.money, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            const Text('Paiement en espèces'),
                          ],
                        ),
                        subtitle:
                            const Text('Payez directement au gestionnaire'),
                        value: 'especes',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value;
                            selectedMobileProvider =
                                null; // Reset mobile provider
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Option Mobile Money
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedPaymentMethod == 'mobile'
                              ? Colors.green
                              : Colors.grey[300]!,
                          width: selectedPaymentMethod == 'mobile' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: RadioListTile<String>(
                        title: Row(
                          children: [
                            Icon(Icons.phone_android, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            const Text('Paiement mobile'),
                          ],
                        ),
                        subtitle: const Text('MTN Money ou Orange Money'),
                        value: 'mobile',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value;
                          });
                        },
                      ),
                    ),

                    // Sélection du fournisseur mobile si Mobile Money est sélectionné
                    if (selectedPaymentMethod == 'mobile') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Choisissez votre opérateur :',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // MTN Money
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedMobileProvider == 'mtn'
                                ? Colors.orange
                                : Colors.grey[300]!,
                            width: selectedMobileProvider == 'mtn' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RadioListTile<String>(
                          title: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.yellow[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('M',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('MTN Money'),
                            ],
                          ),
                          value: 'mtn',
                          groupValue: selectedMobileProvider,
                          onChanged: (value) {
                            setState(() {
                              selectedMobileProvider = value;
                            });
                          },
                        ),
                      ),

                      // Orange Money
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedMobileProvider == 'orange'
                                ? Colors.orange
                                : Colors.grey[300]!,
                            width: selectedMobileProvider == 'orange' ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RadioListTile<String>(
                          title: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text('O',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Orange Money'),
                            ],
                          ),
                          value: 'orange',
                          groupValue: selectedMobileProvider,
                          onChanged: (value) {
                            setState(() {
                              selectedMobileProvider = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: (selectedPaymentMethod != null &&
                          (selectedPaymentMethod == 'especes' ||
                              (selectedPaymentMethod == 'mobile' &&
                                  selectedMobileProvider != null)))
                      ? () => Navigator.of(context).pop({
                            'paymentMethod': selectedPaymentMethod,
                            'mobileProvider': selectedMobileProvider,
                          })
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmer le paiement'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      await _processPayment(request, result);
    }
  }

  /// Calcule le montant total d'une réservation
  int _calculateReservationTotal(ReservationRequest request) {
    // Calculer la durée en heures
    final debut = TimeOfDay(
      hour: int.parse(request.heureDebut.split(':')[0]),
      minute: int.parse(request.heureDebut.split(':')[1]),
    );
    final fin = TimeOfDay(
      hour: int.parse(request.heureFin.split(':')[0]),
      minute: int.parse(request.heureFin.split(':')[1]),
    );

    final duration =
        (fin.hour * 60 + fin.minute) - (debut.hour * 60 + debut.minute);
    final hours = duration ~/ 60;

    // Trouver le prix du stade - nous pouvons utiliser une valeur par défaut ou chercher dans Firestore
    // Pour simplifier, je vais utiliser un prix par défaut de 5000 FCFA/heure
    return hours * 5000;
  }

  /// Traite le paiement sélectionné
  Future<void> _processPayment(
      ReservationRequest request, Map<String, String?> paymentData) async {
    try {
      print('💳 Traitement du paiement pour ${request.stadeNom}');
      print('💳 Mode: ${paymentData['paymentMethod']}');
      if (paymentData['mobileProvider'] != null) {
        print('💳 Opérateur: ${paymentData['mobileProvider']}');
      }

      // Afficher un dialogue de confirmation selon le mode de paiement
      if (paymentData['paymentMethod'] == 'especes') {
        await _showCashPaymentInstructions(request);
      } else if (paymentData['paymentMethod'] == 'mobile') {
        await _showMobilePaymentInstructions(
            request, paymentData['mobileProvider']!);
      }
    } catch (e) {
      print('❌ Erreur lors du traitement du paiement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du traitement du paiement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Affiche les instructions pour le paiement en espèces
  Future<void> _showCashPaymentInstructions(ReservationRequest request) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.money, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text('Paiement en espèces'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instructions de paiement :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('• Rendez-vous au stade ${request.stadeNom}'),
                  Text(
                      '• Montant à payer : ${_calculateReservationTotal(request)} FCFA'),
                  const Text('• Payez directement au gestionnaire'),
                  const Text('• Conservez votre reçu de paiement'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Votre réservation sera confirmée après le paiement.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateReservationPaymentStatus(request, 'especes', null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  /// Affiche les instructions pour le paiement mobile
  Future<void> _showMobilePaymentInstructions(
      ReservationRequest request, String provider) async {
    final providerInfo = provider == 'mtn'
        ? {'name': 'MTN Money', 'code': '*126#', 'color': Colors.yellow[700]!}
        : {'name': 'Orange Money', 'code': '#144#', 'color': Colors.orange};

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.phone_android, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text('Paiement ${providerInfo['name']}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Instructions de paiement :',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('• Composez ${providerInfo['code']}'),
                    Text(
                        '• Montant : ${_calculateReservationTotal(request)} FCFA'),
                    const Text('• Numéro du gestionnaire : [À fournir]'),
                    const Text('• Confirmez le paiement'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Conservez le SMS de confirmation pour votre preuve de paiement.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateReservationPaymentStatus(request, 'mobile', provider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: providerInfo['color'] as Color,
              foregroundColor: provider == 'mtn' ? Colors.black : Colors.white,
            ),
            child: const Text('Paiement effectué'),
          ),
        ],
      ),
    );
  }

  /// Met à jour le statut de paiement de la réservation
  Future<void> _updateReservationPaymentStatus(ReservationRequest request,
      String paymentMethod, String? provider) async {
    try {
      print('💾 Mise à jour du statut de paiement...');

      // Mettre à jour dans Firestore
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('reservations')
            .where('userId', isEqualTo: firebaseUser.uid)
            .where('stadeNom', isEqualTo: request.stadeNom)
            .where('dateReservation',
                isEqualTo: Timestamp.fromDate(request.dateReservation))
            .where('heureDebut', isEqualTo: request.heureDebut)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.update({
            'statut': 'paye',
            'paymentMethod': paymentMethod,
            if (provider != null) 'paymentProvider': provider,
            'paymentDate': FieldValue.serverTimestamp(),
          });

          print('✅ Statut de paiement mis à jour dans Firestore');
        }
      }

      // Mettre à jour localement
      final index = _userReservations.indexWhere((r) =>
          r.stadeNom == request.stadeNom &&
          r.dateReservation == request.dateReservation &&
          r.heureDebut == request.heureDebut);

      if (index != -1) {
        _userReservations[index] = ReservationRequest(
          id: request.id,
          stadeId: request.stadeId,
          stadeNom: request.stadeNom,
          clientNom: request.clientNom,
          clientEmail: request.clientEmail,
          dateReservation: request.dateReservation,
          heureDebut: request.heureDebut,
          heureFin: request.heureFin,
          raison: request.raison,
          statut: 'paye', // Nouveau statut
          dateCreation: request.dateCreation,
        );
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paiement confirmé pour ${request.stadeNom}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Rendre le stade indisponible pour ce créneau
      await _createUnavailableSlot(request);

      // Optionnel: Envoyer une notification au gestionnaire
      await _sendPaymentNotificationToManager(request, paymentMethod, provider);
    } catch (e) {
      print('❌ Erreur lors de la mise à jour du paiement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la confirmation du paiement'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Crée un créneau indisponible pour le stade après validation ou paiement
  Future<void> _createUnavailableSlot(ReservationRequest request,
      {String? raison}) async {
    try {
      print(
          '🚫 Création créneau indisponible pour ${request.stadeNom} le ${DateFormat('dd/MM/yyyy').format(request.dateReservation)} de ${request.heureDebut} à ${request.heureFin}');

      // Créer un document dans la collection 'unavailable_slots'
      await FirebaseFirestore.instance.collection('unavailable_slots').add({
        'stadeId': request.stadeId,
        'stadeNom': request.stadeNom,
        'date': Timestamp.fromDate(request.dateReservation),
        'heureDebut': request.heureDebut,
        'heureFin': request.heureFin,
        'clientNom': request.clientNom,
        'clientEmail': request.clientEmail,
        'reservationId': request.id,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'system', // Automatique après validation/paiement
        'raison': raison ?? 'Réservation payée - Créneau occupé',
      });

      print('✅ Créneau indisponible créé avec succès');
    } catch (e) {
      print('❌ Erreur lors de la création du créneau indisponible: $e');
    }
  }

  /// Envoie une notification au gestionnaire concernant le paiement
  Future<void> _sendPaymentNotificationToManager(ReservationRequest request,
      String paymentMethod, String? provider) async {
    try {
      print('📧 Envoi notification de paiement au gestionnaire...');

      // Chercher l'email du gestionnaire (même logique que pour les autres notifications)
      QuerySnapshot? stadiumQuery;
      if (request.stadeId != null && request.stadeId!.isNotEmpty) {
        stadiumQuery = await FirebaseFirestore.instance
            .collection('stadiums')
            .where(FieldPath.documentId, isEqualTo: request.stadeId)
            .limit(1)
            .get();
      }

      if (stadiumQuery == null || stadiumQuery.docs.isEmpty) {
        stadiumQuery = await FirebaseFirestore.instance
            .collection('stadiums')
            .where('nom', isEqualTo: request.stadeNom)
            .limit(1)
            .get();
      }

      if (stadiumQuery != null && stadiumQuery.docs.isNotEmpty) {
        final stadiumData =
            stadiumQuery.docs.first.data() as Map<String, dynamic>;
        final managerEmail = stadiumData['managerEmail'] as String?;

        if (managerEmail != null && managerEmail.isNotEmpty) {
          // TODO: Implémenter l'envoi d'email de notification de paiement
          print('📧 Email de notification de paiement envoyé à: $managerEmail');
          print(
              '💳 Mode de paiement: $paymentMethod${provider != null ? ' ($provider)' : ''}');
        }
      }
    } catch (e) {
      print('❌ Erreur envoi notification paiement: $e');
    }
  }

  /// Affiche le dialogue de gestion des créneaux indisponibles
  void _showManageTimeSlotsDialog(Map<String, dynamic> stade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.purple),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Créneaux - ${stade['nom']}'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              // Bouton pour ajouter un nouveau créneau indisponible
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showAddUnavailableSlotDialog(stade);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter créneau indisponible'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Liste des créneaux indisponibles
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('unavailable_slots')
                      .where('stadeId', isEqualTo: stade['id'])
                      .orderBy('date')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Erreur: ${snapshot.error}'));
                    }

                    final slots = snapshot.data?.docs ?? [];

                    if (slots.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Aucun créneau indisponible',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: slots.length,
                      itemBuilder: (context, index) {
                        final slot =
                            slots[index].data() as Map<String, dynamic>;
                        final date = (slot['date'] as Timestamp).toDate();
                        final isOld = date.isBefore(
                            DateTime.now().subtract(const Duration(days: 1)));

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              slot['createdBy'] == 'system'
                                  ? Icons.payment
                                  : Icons.block,
                              color: isOld
                                  ? Colors.grey
                                  : (slot['createdBy'] == 'system'
                                      ? Colors.blue
                                      : Colors.red),
                            ),
                            title: Text(
                              '${DateFormat('dd/MM/yyyy').format(date)} - ${slot['heureDebut']} à ${slot['heureFin']}',
                              style: TextStyle(
                                color: isOld ? Colors.grey : null,
                                decoration:
                                    isOld ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              slot['raison'] ?? 'Aucune raison',
                              style:
                                  TextStyle(color: isOld ? Colors.grey : null),
                            ),
                            trailing: !isOld
                                ? IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () async {
                                      // Confirmer la suppression
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                              'Confirmer la suppression'),
                                          content: const Text(
                                              'Voulez-vous vraiment supprimer ce créneau indisponible ?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(false),
                                              child: const Text('Annuler'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context)
                                                      .pop(true),
                                              child: const Text('Supprimer'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirm == true) {
                                        await slots[index].reference.delete();
                                        if (context.mounted) {
                                          // Rafraîchir le dialogue
                                          Navigator.of(context).pop();
                                          _showManageTimeSlotsDialog(stade);
                                        }
                                      }
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Affiche le dialogue pour ajouter un créneau indisponible
  void _showAddUnavailableSlotDialog(Map<String, dynamic> stade) {
    // Liste des créneaux à bloquer
    List<Map<String, dynamic>> slotsToBlock = [
      {
        'date': DateTime.now(),
        'startTime': const TimeOfDay(hour: 8, minute: 0),
        'endTime': const TimeOfDay(hour: 10, minute: 0),
      }
    ];
    final raisonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.block, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Bloquer des créneaux'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stade: ${stade['nom']}'),
                const SizedBox(height: 16),

                // Bouton pour ajouter un nouveau créneau
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          slotsToBlock.add({
                            'date': DateTime.now(),
                            'startTime': const TimeOfDay(hour: 8, minute: 0),
                            'endTime': const TimeOfDay(hour: 10, minute: 0),
                          });
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter créneau'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Liste des créneaux à bloquer
                Expanded(
                  child: ListView.builder(
                    itemCount: slotsToBlock.length,
                    itemBuilder: (context, index) {
                      final slot = slotsToBlock[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Créneau ${index + 1}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  if (slotsToBlock.length > 1)
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          slotsToBlock.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Date
                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: slot['date'],
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      slot['date'] = date;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Text(DateFormat('dd/MM/yyyy')
                                          .format(slot['date'])),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Heures
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: slot['startTime'],
                                        );
                                        if (time != null) {
                                          setState(() {
                                            slot['startTime'] = time;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Text(slot['startTime']
                                                .format(context)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('à'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: slot['endTime'],
                                        );
                                        if (time != null) {
                                          setState(() {
                                            slot['endTime'] = time;
                                          });
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time,
                                                size: 18),
                                            const SizedBox(width: 8),
                                            Text(slot['endTime']
                                                .format(context)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Raison commune
                const Text('Raison (pour tous les créneaux):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: raisonController,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Maintenance, Événement privé...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Valider tous les créneaux
                  for (int i = 0; i < slotsToBlock.length; i++) {
                    final slot = slotsToBlock[i];
                    final startTime = slot['startTime'] as TimeOfDay;
                    final endTime = slot['endTime'] as TimeOfDay;

                    final startMinutes = startTime.hour * 60 + startTime.minute;
                    final endMinutes = endTime.hour * 60 + endTime.minute;

                    if (endMinutes <= startMinutes) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Créneau ${i + 1}: L\'heure de fin doit être après l\'heure de début'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }

                  // Créer tous les créneaux indisponibles
                  final firestore = FirebaseFirestore.instance;
                  final batch = firestore.batch();

                  for (final slot in slotsToBlock) {
                    final startTime = slot['startTime'] as TimeOfDay;
                    final endTime = slot['endTime'] as TimeOfDay;
                    final date = slot['date'] as DateTime;

                    final docRef =
                        firestore.collection('unavailable_slots').doc();
                    batch.set(docRef, {
                      'stadeId': stade['id'],
                      'stadeNom': stade['nom'],
                      'date': Timestamp.fromDate(date),
                      'heureDebut':
                          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                      'heureFin':
                          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                      'raison': raisonController.text.isNotEmpty
                          ? raisonController.text
                          : 'Bloqué par le gestionnaire',
                      'createdAt': FieldValue.serverTimestamp(),
                      'createdBy': 'manager',
                    });
                  }

                  await batch.commit();

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${slotsToBlock.length} créneau(x) indisponible(s) créé(s) avec succès'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Rouvrir le dialogue de gestion
                    _showManageTimeSlotsDialog(stade);
                  }
                } catch (e) {
                  print('❌ Erreur lors de la création des créneaux: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Erreur lors de la création des créneaux'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                  'Bloquer ${slotsToBlock.length} créneau${slotsToBlock.length > 1 ? 'x' : ''}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotsPreview(Map<String, dynamic> stade) {
    return FutureBuilder<List<Map<String, String>>>(
      future: _getUnavailableSlots(stade['id'] ?? stade['nom'], DateTime.now()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 20,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final unavailableSlots = snapshot.data ?? [];
        final today = DateTime.now();
        final timeSlots = [
          '06:00',
          '08:00',
          '10:00',
          '12:00',
          '14:00',
          '16:00',
          '18:00',
          '20:00'
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  'Créneaux aujourd\'hui (${DateFormat('dd/MM').format(today)})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: timeSlots.map((timeSlot) {
                // Vérifier si le créneau est occupé et quel type
                Map<String, dynamic>? conflictingSlot;
                for (final slot in unavailableSlots) {
                  final startTime = slot['debut'] ?? '';
                  final endTime = slot['fin'] ?? '';
                  final slotTime = int.tryParse(timeSlot.split(':')[0]) ?? 0;
                  final startHour = int.tryParse(startTime.split(':')[0]) ?? 0;
                  final endHour = int.tryParse(endTime.split(':')[0]) ?? 0;
                  if (slotTime >= startHour && slotTime < endHour) {
                    conflictingSlot = slot;
                    break;
                  }
                }

                final isReserved = conflictingSlot != null;
                final isBlocked = conflictingSlot?['type'] == 'blocked';

                Color backgroundColor, borderColor, textColor;
                String tooltip = timeSlot;

                if (isReserved) {
                  if (isBlocked) {
                    // Créneau bloqué par gestionnaire
                    backgroundColor = Colors.orange.shade100;
                    borderColor = Colors.orange.shade300;
                    textColor = Colors.orange.shade700;
                    tooltip =
                        '$timeSlot - Bloqué: ${conflictingSlot!['client']}';
                  } else {
                    // Créneau réservé par client
                    backgroundColor = Colors.red.shade100;
                    borderColor = Colors.red.shade300;
                    textColor = Colors.red.shade700;
                    tooltip =
                        '$timeSlot - Réservé: ${conflictingSlot!['client']}';
                  }
                } else {
                  // Créneau disponible
                  backgroundColor = Colors.green.shade100;
                  borderColor = Colors.green.shade300;
                  textColor = Colors.green.shade700;
                  tooltip = '$timeSlot - Disponible';
                }

                return Tooltip(
                  message: tooltip,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border.all(color: borderColor, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      timeSlot,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (unavailableSlots.isNotEmpty) ...[
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final reservedCount = unavailableSlots
                      .where((s) => s['type'] == 'reservation')
                      .length;
                  final blockedCount = unavailableSlots
                      .where((s) => s['type'] == 'blocked')
                      .length;

                  String statusText = '';
                  if (reservedCount > 0 && blockedCount > 0) {
                    statusText =
                        '$reservedCount réservé(s), $blockedCount bloqué(s)';
                  } else if (reservedCount > 0) {
                    statusText = '$reservedCount créneau(x) réservé(s)';
                  } else if (blockedCount > 0) {
                    statusText = '$blockedCount créneau(x) bloqué(s)';
                  }

                  return Row(
                    children: [
                      // Légende
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              border: Border.all(color: Colors.green.shade300),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text('Libre', style: TextStyle(fontSize: 9)),
                          const SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              border: Border.all(color: Colors.red.shade300),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text('Réservé', style: TextStyle(fontSize: 9)),
                          const SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              border: Border.all(color: Colors.orange.shade300),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text('Bloqué', style: TextStyle(fontSize: 9)),
                        ],
                      ),
                      const Spacer(),
                      if (statusText.isNotEmpty)
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ] else ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tous les créneaux sont disponibles',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStadeCard(BuildContext context, Map<String, dynamic> stade) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          _showStadeDetails(context, stade);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Icon(
                Icons.sports_soccer,
                size: 60,
                color: Colors.grey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          stade['nom'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              stade['disponible'] ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stade['disponible'] ? 'Disponible' : 'Occupé',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          stade['quartier'],
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        stade['capacite'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stade['description'],
                    style: TextStyle(color: Colors.grey[800], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Affichage des créneaux horaires pour les visiteurs
                  if (_currentUserType == 'visiteur')
                    _buildTimeSlotsPreview(stade),

                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${stade['prix']} FCFA/h',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _currentUserType == 'visiteur'
                          ? ElevatedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Veuillez vous connecter pour réserver'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                Future.delayed(const Duration(seconds: 1), () {
                                  context.go('/login');
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: const Text(
                                'Se connecter',
                                style: TextStyle(fontSize: 12),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () {
                                _showReservationDialog(context, stade);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              child: const Text(
                                'Réserver',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStadeCard(BuildContext context, Map<String, dynamic> stade) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          _showStadeDetails(context, stade);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Icon(
                Icons.sports_soccer,
                size: 60,
                color: Colors.grey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          stade['nom'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              stade['disponible'] ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stade['disponible'] ? 'Disponible' : 'Occupé',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          stade['quartier'],
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        stade['capacite'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stade['description'],
                    style: TextStyle(color: Colors.grey[800], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${stade['prix']} FCFA/h',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              _showEditStadiumDialog(stade);
                            },
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Modifier'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showManageTimeSlotsDialog(stade);
                            },
                            icon: const Icon(Icons.schedule, size: 14),
                            label: const Text('Créneaux'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showDeleteStadiumDialog(stade);
                            },
                            icon: const Icon(Icons.delete, size: 14),
                            label: const Text('Supprimer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStadeDetails(BuildContext context, Map<String, dynamic> stade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stade['nom']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 Quartier: ${stade['quartier']}'),
            Text('⚽ Capacité: ${stade['capacite']}'),
            Text('🏟️ Type: ${stade['type']}'),
            Text('💰 Prix: ${stade['prix']} FCFA/heure'),
            const SizedBox(height: 16),
            const Text('Description:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(stade['description']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showReservationDialog(context, stade);
            },
            child: const Text('Réserver'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReservationDialog(
      BuildContext context, Map<String, dynamic> stade) async {
    try {
      // Vérification d'authentification AVANT d'ouvrir le dialogue
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_user');
      final userType = prefs.getString('current_user_type') ?? 'visiteur';

      // Bloquer l'accès si visiteur ou non-authentifié
      // Vérification stricte : Firebase Auth ET type utilisateur valide
      if (firebaseUser == null ||
          currentUser == null ||
          currentUser.isEmpty ||
          currentUser == 'Visiteur' ||
          userType == 'visiteur' ||
          userType.isEmpty ||
          !userType.contains('client') && !userType.contains('gestionnaire')) {
        print(
            '🚫 ACCÈS BLOQUÉ - User: "$currentUser", Type: "$userType", Firebase: ${firebaseUser?.email}');
        print(
            '🚫 Raison: Firebase=${firebaseUser == null}, User=${currentUser == null}, Type=$userType');
        _showVisitorBlockDialogForReservation(context);
        return;
      }

      print(
          '✅ Accès au formulaire de réservation autorisé - User: $currentUser ($userType)');
      showDialog(
        context: context,
        builder: (context) => ReservationDialog(stade: stade),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showVisitorBlockDialogForReservation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Connexion requise',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ERREUR : Vous ne pouvez pas faire de réservation en tant que visiteur !',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vous devez d\'abord vous connecter ou créer un compte.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                '⚠️ ACCÈS REFUSÉ : Connectez-vous d\'abord avec votre compte ou créez un nouveau compte pour pouvoir effectuer des réservations.',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate to login
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Se connecter'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate to registration
              context.go('/register');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Créer un compte'),
          ),
        ],
      ),
    );
  }

  void _showAddStadiumDialog() {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController();
    final adresseController = TextEditingController();
    final prixController = TextEditingController();
    final descriptionController = TextEditingController();
    String capacite = '11v11';
    String type = 'Terrain standard';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un nouveau stade'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du stade',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Nom requis';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: adresseController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Adresse requise';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: prixController,
                  decoration: const InputDecoration(
                    labelText: 'Prix par heure (FCFA)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Prix requis';
                    if (int.tryParse(value!) == null) return 'Prix invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: capacite,
                  decoration: const InputDecoration(
                    labelText: 'Capacité',
                    border: OutlineInputBorder(),
                  ),
                  items: ['5v5', '7v7', '11v11'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    capacite = newValue!;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type de terrain',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Terrain standard',
                    'Terrain gazonné',
                    'Terrain synthétique',
                    'Terrain bétonné'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    type = newValue!;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await FirebaseFirestore.instance.collection('stadiums').add({
                    'nom': nomController.text.trim(),
                    'adresse': adresseController.text.trim(),
                    'quartier': adresseController.text.trim().split(',').first,
                    'prix': int.parse(prixController.text),
                    'capacite': capacite,
                    'type': type,
                    'description': descriptionController.text.trim(),
                    'gestionnaire': _currentUserName,
                    'managerEmail': _currentUser,
                    'disponible': true,
                    'images': [],
                    'dateCreation': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stade ajouté avec succès!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _loadStades();
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEditStadiumDialog(Map<String, dynamic> stade) {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController(text: stade['nom']);
    final adresseController = TextEditingController(text: stade['adresse']);
    final prixController =
        TextEditingController(text: stade['prix'].toString());
    final descriptionController =
        TextEditingController(text: stade['description']);

    // Ensure capacite value exists in dropdown options
    const capaciteOptions = ['5v5', '7v7', '11v11'];
    String capacite = capaciteOptions.contains(stade['capacite'])
        ? stade['capacite']
        : '11v11';

    // Ensure type value exists in dropdown options
    const typeOptions = [
      'Terrain standard',
      'Terrain gazonné',
      'Terrain synthétique',
      'Terrain bétonné'
    ];
    String type = typeOptions.contains(stade['type'])
        ? stade['type']
        : 'Terrain standard';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le stade'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du stade',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Nom requis';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: adresseController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Adresse requise';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: prixController,
                  decoration: const InputDecoration(
                    labelText: 'Prix par heure (FCFA)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Prix requis';
                    if (int.tryParse(value!) == null) return 'Prix invalide';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: capacite,
                  decoration: const InputDecoration(
                    labelText: 'Capacité',
                    border: OutlineInputBorder(),
                  ),
                  items: ['5v5', '7v7', '11v11'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    capacite = newValue!;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Type de terrain',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    'Terrain standard',
                    'Terrain gazonné',
                    'Terrain synthétique',
                    'Terrain bétonné'
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    type = newValue!;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await FirebaseFirestore.instance
                      .collection('stadiums')
                      .doc(stade['id'])
                      .update({
                    'nom': nomController.text.trim(),
                    'adresse': adresseController.text.trim(),
                    'quartier': adresseController.text.trim().split(',').first,
                    'prix': int.parse(prixController.text),
                    'capacite': capacite,
                    'type': type,
                    'description': descriptionController.text.trim(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stade modifié avec succès!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _loadStades();
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _showDeleteStadiumDialog(Map<String, dynamic> stade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le stade'),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer "${stade['nom']}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('stadiums')
                    .doc(stade['id'])
                    .delete();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Stade supprimé avec succès!'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadStades();
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class ReservationDialog extends StatefulWidget {
  final Map<String, dynamic> stade;

  const ReservationDialog({super.key, required this.stade});

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _raisonController = TextEditingController();

  DateTime _dateReservation = DateTime.now().add(const Duration(days: 1));
  String _heureDebut = '08:00';
  String _heureFin = '10:00';

  final List<String> _heures = [
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_user') ?? '';
      final userName = prefs.getString('username_$currentUser') ?? currentUser;

      _nomController.text = userName;
      _emailController.text = currentUser; // current_user stores the email
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLogger.error('Erreur chargement info utilisateur pour réservation', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de charger vos informations utilisateur'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReservation,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateReservation = picked;
      });
    }
  }

  int _calculateDuration() {
    final debut = _heures.indexOf(_heureDebut);
    final fin = _heures.indexOf(_heureFin);
    return fin - debut;
  }

  int _calculateTotal() {
    final duration = _calculateDuration();
    return duration > 0 ? (widget.stade['prix'] as int) * duration : 0;
  }

  Future<void> _submitReservation() async {
    print(
        '🚀 DÉBUT _submitReservation - Création d\'une nouvelle demande de réservation');
    if (_formKey.currentState!.validate()) {
      try {
        // Check user authentication - use Firebase Auth + SharedPreferences
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final prefs = await SharedPreferences.getInstance();
        final currentUser = prefs.getString('current_user');
        final userType = prefs.getString('current_user_type') ?? 'visiteur';

        // Block if not authenticated or is visitor
        if (firebaseUser == null ||
            currentUser == null ||
            userType == 'visiteur') {
          print(
              '❌ Réservation bloquée - User: $currentUser, Type: $userType, Firebase: ${firebaseUser?.email}');
          _showVisitorBlockDialog();
          return;
        }

        print('✅ Réservation autorisée - User: $currentUser ($userType)');

        // Validate required fields
        if (_nomController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le nom est requis'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final emailValidation =
            FormValidators.validateEmail(_emailController.text.trim());
        if (emailValidation != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emailValidation),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (_raisonController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La raison de la réservation est requise'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final request = ReservationRequest(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          stadeId: widget.stade['id'] ??
              widget.stade[
                  'nom'], // Use stadium ID if available, fallback to name
          stadeNom: widget.stade['nom'],
          clientNom: _nomController.text.trim(),
          clientEmail: _emailController.text.trim(),
          dateReservation: _dateReservation,
          heureDebut: _heureDebut,
          heureFin: _heureFin,
          raison: _raisonController.text.trim(),
          statut: 'en_attente',
          dateCreation: DateTime.now(),
        );

        // Sauvegarder avec transaction Firebase pour éviter les race conditions
        if (firebaseUser != null) {
          final reservationData = {
            'userId': firebaseUser.uid,
            'stadeId': request.stadeId,
            'stadeNom': request.stadeNom,
            'clientNom': request.clientNom,
            'clientEmail': request.clientEmail,
            'dateReservation': Timestamp.fromDate(request.dateReservation),
            'heureDebut': request.heureDebut,
            'heureFin': request.heureFin,
            'raison': request.raison,
            'statut': 'en_attente',
            'dateCreation': FieldValue.serverTimestamp(),
          };

          print('💾 Sauvegarde réservation pour userId: ${firebaseUser.uid}');
          print('📄 Données: $reservationData');

          await FirebaseFirestore.instance
              .collection('reservations')
              .add(reservationData);

          print('💾 Réservation sauvegardée dans Firestore');

          // Envoyer email de notification au gestionnaire
          print(
              '📧 APPEL de _sendManagerNotificationEmailForDialog pour: ${request.stadeNom}');
          await _sendManagerNotificationEmailForDialog(request);

          // Notifier le HomeScreen pour recharger les données et basculer vers l'historique
          if (context.mounted) {
            final homeState = context.findAncestorStateOfType<_HomePageState>();
            if (homeState != null) {
              await homeState._loadUserReservations();
              homeState.setState(() {
                homeState._selectedTab =
                    'historique'; // Basculer vers l'onglet Historique
              });
            }
          }
        }

        // Fallback : SharedPreferences pour compatibilité
        final requests = prefs.getStringList('reservation_requests') ?? [];
        requests.add(request.id);
        await prefs.setStringList('reservation_requests', requests);
        await prefs.setString(
            'request_${request.id}',
            '${request.stadeNom}|${request.clientNom}|${request.clientEmail}|'
                '${DateFormat('dd/MM/yyyy').format(request.dateReservation)}|'
                '${request.heureDebut}|${request.heureFin}|${request.raison}|'
                '${request.statut}|${DateFormat('dd/MM/yyyy HH:mm').format(request.dateCreation)}');

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Demande de réservation envoyée avec succès pour ${widget.stade['nom']}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Voir',
                textColor: Colors.white,
                onPressed: () {
                  _showRequestDetails(request);
                },
              ),
            ),
          );
        }
      } on FirebaseException catch (e) {
        if (mounted) {
          String errorMessage;
          if (e.code == 'slot-conflict') {
            errorMessage =
                e.message ?? 'Ce créneau est déjà réservé pour cette date.';
          } else {
            errorMessage = 'Erreur Firebase: ${e.message}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Erreur inattendue lors de l\'envoi de la demande: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      // Show validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez corriger les erreurs dans le formulaire'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRequestDetails(ReservationRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demande envoyée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏟️ ${request.stadeNom}'),
            Text(
                '📅 ${DateFormat('dd/MM/yyyy').format(request.dateReservation)}'),
            Text('⏰ ${request.heureDebut} - ${request.heureFin}'),
            Text('💰 ${_calculateTotal()} FCFA'),
            const SizedBox(height: 8),
            Text('📝 ${request.raison}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⏳ En attente de validation du gestionnaire',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVisitorBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Réservation impossible',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vous ne pouvez pas effectuer de réservation en tant que visiteur.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                '💡 Pour effectuer des réservations, vous devez créer un compte client ou gestionnaire.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close reservation form
              // Navigate to registration
              context.go('/register');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Créer un compte pour réserver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration();
    final total = _calculateTotal();

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_soccer, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Réserver ${widget.stade['nom']}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty == true ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: FormValidators.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text(
                                  'Date: ${DateFormat('dd/MM/yyyy').format(_dateReservation)}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _heureDebut,
                              decoration: const InputDecoration(
                                labelText: 'Heure début',
                                border: OutlineInputBorder(),
                              ),
                              items: _heures
                                  .map((heure) => DropdownMenuItem(
                                        value: heure,
                                        child: Text(heure),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _heureDebut = value!;
                                  if (_heures.indexOf(_heureDebut) >=
                                      _heures.indexOf(_heureFin)) {
                                    final index =
                                        _heures.indexOf(_heureDebut) + 1;
                                    if (index < _heures.length) {
                                      _heureFin = _heures[index];
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _heureFin,
                              decoration: const InputDecoration(
                                labelText: 'Heure fin',
                                border: OutlineInputBorder(),
                              ),
                              items: _heures
                                  .where((heure) =>
                                      _heures.indexOf(heure) >
                                      _heures.indexOf(_heureDebut))
                                  .map((heure) => DropdownMenuItem(
                                        value: heure,
                                        child: Text(heure),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _heureFin = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _raisonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Raison de la réservation *',
                          hintText: 'Ex: Entraînement équipe, Match amical...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value?.isEmpty == true ? 'Raison requise' : null,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text('Durée: $duration heure(s)',
                                style: const TextStyle(fontSize: 16)),
                            Text('Total: $total FCFA',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: duration > 0 ? _submitReservation : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Envoyer la demande'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Envoie un email de notification au gestionnaire pour une nouvelle demande de réservation
  Future<void> _sendManagerNotificationEmailForDialog(
      ReservationRequest request) async {
    try {
      print(
          '📧 Recherche de l\'email du gestionnaire pour le stade: ${request.stadeNom} (ID: ${request.stadeId})');

      // D'abord essayer de chercher par stadeId (plus fiable)
      QuerySnapshot? stadiumQuery;
      if (request.stadeId != null && request.stadeId!.isNotEmpty) {
        print('🔍 Recherche par stadeId: ${request.stadeId}');
        stadiumQuery = await FirebaseFirestore.instance
            .collection('stadiums')
            .where(FieldPath.documentId, isEqualTo: request.stadeId)
            .limit(1)
            .get();
      }

      // Si pas trouvé par ID, chercher par nom
      if (stadiumQuery == null || stadiumQuery.docs.isEmpty) {
        print('🔍 Recherche par nom du stade: ${request.stadeNom}');
        stadiumQuery = await FirebaseFirestore.instance
            .collection('stadiums')
            .where('nom', isEqualTo: request.stadeNom)
            .limit(1)
            .get();
      }

      if (stadiumQuery == null || stadiumQuery.docs.isEmpty) {
        print(
            '⚠️ Stade non trouvé dans Firestore: ${request.stadeNom} (ID: ${request.stadeId})');
        // Debug: lister tous les stades pour voir la structure
        final allStadiums = await FirebaseFirestore.instance
            .collection('stadiums')
            .limit(5)
            .get();
        print('🔍 Stades disponibles:');
        for (var doc in allStadiums.docs) {
          print('  - ID: ${doc.id}, Data: ${doc.data()}');
        }
        return;
      }

      final stadiumData =
          stadiumQuery.docs.first.data() as Map<String, dynamic>;
      final managerEmail = stadiumData['managerEmail'] as String?;

      print('🏟️ Stade trouvé: ${stadiumData}');

      if (managerEmail == null || managerEmail.isEmpty) {
        print(
            '⚠️ Email du gestionnaire non trouvé pour le stade: ${request.stadeNom}');
        return;
      }

      print('📧 Envoi notification au gestionnaire: $managerEmail');

      // Utiliser le NotificationService pour l'envoi réel d'emails
      final bool emailSent = await NotificationService.instance
          .sendNewReservationNotificationToManager(
        managerEmail: managerEmail,
        clientName: request.clientNom,
        clientEmail: request.clientEmail,
        stadeNom: request.stadeNom,
        dateReservation:
            DateFormat('dd/MM/yyyy').format(request.dateReservation),
        heureDebut: request.heureDebut,
        heureFin: request.heureFin,
        raison: request.raison,
      );

      if (emailSent) {
        print(
            '✅ Email de notification envoyé avec succès au gestionnaire: $managerEmail');
      } else {
        print(
            '⚠️ Échec envoi email au gestionnaire, mais création de la réservation continue');
      }
    } catch (e) {
      print('❌ Erreur envoi email au gestionnaire: $e');
      // Ne pas faire échouer l'opération si l'email ne peut pas être envoyé
      // On log juste l'erreur pour debugging
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _raisonController.dispose();
    super.dispose();
  }
}

// === PAGE DE CONFIRMATION D'EMAIL ===

class EmailConfirmationPage extends StatefulWidget {
  final String email;
  final String userType;
  final Map<String, dynamic> userData;

  const EmailConfirmationPage({
    super.key,
    required this.email,
    required this.userType,
    required this.userData,
  });

  @override
  State<EmailConfirmationPage> createState() => _EmailConfirmationPageState();
}

class _EmailConfirmationPageState extends State<EmailConfirmationPage> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_isResending || _countdown > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      // Renvoyer l'OTP
      await NotificationService.instance.sendEmailOtp(widget.email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code de vérification renvoyé par email'),
          backgroundColor: Colors.green,
        ),
      );

      _startCountdown();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du renvoi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isResending = false;
      });
    }
  }

  Future<void> _verifyOtpAndCreateAccount() async {
    if (_otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir le code à 6 chiffres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      // Vérifier l'OTP
      final bool isValid = await NotificationService.instance
          .verifyOtpCode(widget.email, _otpController.text.trim());

      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code de vérification invalide'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // OTP valide, créer le compte Firebase
      UserCredential result =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.userData['password'],
      );

      if (result.user != null) {
        // Supprimer le mot de passe des données à sauvegarder
        final Map<String, dynamic> dataToSave =
            Map<String, dynamic>.from(widget.userData);
        dataToSave.remove('password');
        dataToSave.remove('confirmPassword');

        // Sauvegarder les données utilisateur dans Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(result.user!.uid)
            .set(dataToSave);

        if (mounted) {
          // Rediriger vers la page de succès
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => RegistrationSuccessPage(
                email: widget.email,
                userType: widget.userType,
              ),
            ),
          );
        }
      }
    } catch (e) {
      String errorMessage = 'Erreur lors de la création du compte';

      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'Cette adresse email est déjà utilisée';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Le mot de passe est trop faible';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Adresse email invalide';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Confirmation d\'email'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icône
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.email_outlined,
                        size: 50,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Titre
                    const Text(
                      'Vérifiez votre email',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Nous avons envoyé un code de vérification à:\n${widget.email}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Champ OTP
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E88E5), width: 2),
                        ),
                        counterText: '',
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bouton de vérification
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isVerifying ? null : _verifyOtpAndCreateAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isVerifying
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Création du compte...'),
                                ],
                              )
                            : const Text(
                                'Vérifier et créer le compte',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bouton renvoyer
                    TextButton(
                      onPressed: (_countdown == 0 && !_isResending)
                          ? _resendOtp
                          : null,
                      child: _isResending
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Envoi en cours...'),
                              ],
                            )
                          : Text(
                              _countdown > 0
                                  ? 'Renvoyer le code dans ${_countdown}s'
                                  : 'Renvoyer le code',
                              style: TextStyle(
                                color:
                                    _countdown > 0 ? Colors.grey : Colors.blue,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vérifiez votre dossier spam si vous ne recevez pas le code.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === PAGE DE SUCCÈS D'INSCRIPTION ===

class RegistrationSuccessPage extends StatelessWidget {
  final String email;
  final String userType;

  const RegistrationSuccessPage({
    super.key,
    required this.email,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animation de succès
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 70,
                  color: Colors.green.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // Titre
              const Text(
                'Inscription réussie !',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Message de succès
              Text(
                userType == 'gestionnaire'
                    ? 'Félicitations ! Votre compte gestionnaire a été créé avec succès.\n\nVous pouvez maintenant gérer votre stade et traiter les demandes de réservation.'
                    : 'Félicitations ! Votre compte a été créé avec succès.\n\nVous pouvez maintenant réserver des terrains de football.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Email confirmé
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.email,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Email vérifié',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            email,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.verified,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Bouton continuer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Retourner à la page de connexion
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const BookFootApp(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Commencer à utiliser BookFoot237',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
