import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reservation_request.dart';
import '../utils/app_logger.dart';

class FirebaseReservationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _collection = 'reservations';

  /// Créer une nouvelle réservation
  static Future<String?> createReservation(ReservationRequest reservation) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'Utilisateur non connecté';
      }

      final data = reservation.toJson();
      data.remove('id');
      data['clientEmail'] = user.email;
      data['dateCreation'] = FieldValue.serverTimestamp();
      data['statut'] = 'en_attente';

      // S'assurer que stadiumManager est présent
      if (!data.containsKey('stadiumManager') || data['stadiumManager'] == null || data['stadiumManager'].isEmpty) {
        throw 'Le gestionnaire du stade est manquant';
      }

      AppLogger.info('🔧 DEBUG - Création réservation:');
      AppLogger.info('   - stadiumManager: ${data['stadiumManager']}');
      AppLogger.info('   - stadeId: ${data['stadeId']}');
      AppLogger.info('   - stadeNom: ${data['stadeNom']}');
      AppLogger.info('   - clientEmail: ${data['clientEmail']}');
      AppLogger.info('   - dateReservation: ${data['dateReservation']}');
      AppLogger.info('   - Data complète: $data');

      final docRef = await _firestore.collection(_collection).add(data);

      AppLogger.info('✅ Réservation créée avec succès: ${docRef.id}');

      // Vérification immédiate après création
      final createdDoc = await _firestore.collection(_collection).doc(docRef.id).get();
      if (createdDoc.exists) {
        final createdData = createdDoc.data()!;
        AppLogger.info('🔍 Vérification document créé:');
        AppLogger.info('   - stadiumManager dans Firebase: ${createdData['stadiumManager']}');
        AppLogger.info('   - Document complet: $createdData');
      }

      return docRef.id;
    } catch (e) {
      AppLogger.error('❌ Erreur lors de la création de la réservation: $e');
      return null;
    }
  }

  /// Récupérer les réservations d'un client
  static Future<List<ReservationRequest>> getClientReservations(String clientEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('clientEmail', isEqualTo: clientEmail)
          .get();

      final reservations = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReservationRequest.fromJson(data);
      }).toList();

      // Tri côté client en attendant l'index Firestore
      reservations.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      return reservations;
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des réservations du client: $e');
      return [];
    }
  }

  /// Récupérer les réservations d'un gestionnaire par ID de stade
  static Future<List<ReservationRequest>> getManagerReservations(String stadeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('stadeId', isEqualTo: stadeId)
          .orderBy('dateCreation', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReservationRequest.fromJson(data);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des réservations du gestionnaire: $e');
      return [];
    }
  }

  /// Récupérer les réservations d'un gestionnaire par email
  static Future<List<ReservationRequest>> getManagerReservationsByEmail(String managerEmail) async {
    try {
      AppLogger.info('🔧 DEBUG - Recherche réservations pour gestionnaire: $managerEmail');

      // NOUVELLE APPROCHE: Récupérer directement les réservations par stadiumManager
      // Ceci évite le besoin d'un index complexe
      final reservationsSnapshot = await _firestore
          .collection(_collection)
          .where('stadiumManager', isEqualTo: managerEmail)
          .get();

      AppLogger.info('📊 Réservations trouvées pour $managerEmail: ${reservationsSnapshot.docs.length}');

      List<ReservationRequest> allReservations = [];

      for (var reservationDoc in reservationsSnapshot.docs) {
        final data = reservationDoc.data();
        data['id'] = reservationDoc.id;
        final reservation = ReservationRequest.fromJson(data);
        allReservations.add(reservation);

        AppLogger.info('   ✅ Réservation: ${reservation.id} par ${reservation.clientNom} (${reservation.statut})');
      }

      // Tri côté client par date de création (plus récent en premier)
      allReservations.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      AppLogger.info('🎯 Total réservations retournées pour $managerEmail: ${allReservations.length}');
      return allReservations;
    } catch (e) {
      AppLogger.error('❌ Erreur lors de la récupération des réservations par email gestionnaire: $e');
      return [];
    }
  }

  /// Mettre à jour le statut d'une réservation
  static Future<bool> updateReservationStatus(String reservationId, String newStatus) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'Utilisateur non connecté';
      }

      await _firestore.collection(_collection).doc(reservationId).update({
        'statut': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Statut de réservation mis à jour: $reservationId -> $newStatus');
      return true;
    } catch (e) {
      AppLogger.error('Erreur lors de la mise à jour du statut: $e');
      return false;
    }
  }

  /// Supprimer une réservation
  static Future<bool> deleteReservation(String reservationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'Utilisateur non connecté';
      }

      await _firestore.collection(_collection).doc(reservationId).delete();

      AppLogger.info('Réservation supprimée: $reservationId');
      return true;
    } catch (e) {
      AppLogger.error('Erreur lors de la suppression de la réservation: $e');
      return false;
    }
  }

  /// Récupérer une réservation par ID
  static Future<ReservationRequest?> getReservationById(String reservationId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(reservationId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return ReservationRequest.fromJson(data);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération de la réservation: $e');
      return null;
    }
  }

  /// Vérifier si l'utilisateur peut gérer cette réservation
  static Future<bool> canManageReservation(String reservationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection(_collection).doc(reservationId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return data['clientEmail'] == user.email;
    } catch (e) {
      AppLogger.error('Erreur lors de la vérification des permissions: $e');
      return false;
    }
  }
}