import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/app_logger.dart';

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