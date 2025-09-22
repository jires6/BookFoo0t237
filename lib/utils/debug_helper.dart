import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_reservation_service.dart';
import '../models/reservation_request.dart';
import 'app_logger.dart';

class DebugHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Créer une réservation de test pour vérifier le système
  static Future<void> createTestReservation() async {
    try {
      AppLogger.info('🔧 DEBUG - Création d\'une réservation de test...');

      final testReservation = ReservationRequest(
        id: '',
        stadeId: 'test-stade-id',
        stadeNom: 'Stade de Test',
        stadiumManager: 'gestionnaire@test.com',
        clientNom: 'Client Test',
        clientEmail: 'client@test.com',
        dateReservation: DateTime.now().add(Duration(days: 1)),
        heureDebut: '14:00',
        heureFin: '16:00',
        raison: 'Test de réservation pour debugging',
        statut: 'en_attente',
        dateCreation: DateTime.now(),
      );

      final reservationId = await FirebaseReservationService.createReservation(testReservation);

      if (reservationId != null) {
        AppLogger.info('✅ Réservation de test créée avec succès: $reservationId');

        // Vérifier immédiatement
        await checkReservationExists(reservationId);
        await checkManagerCanSeeReservation('gestionnaire@test.com');
      } else {
        AppLogger.error('❌ Échec de création de la réservation de test');
      }
    } catch (e) {
      AppLogger.error('❌ Erreur lors de la création de réservation de test: $e');
    }
  }

  /// Vérifier qu'une réservation existe dans Firebase
  static Future<void> checkReservationExists(String reservationId) async {
    try {
      AppLogger.info('🔍 Vérification de l\'existence de la réservation: $reservationId');

      final doc = await _firestore.collection('reservations').doc(reservationId).get();

      if (doc.exists) {
        final data = doc.data()!;
        AppLogger.info('✅ Réservation trouvée:');
        AppLogger.info('   - ID: ${doc.id}');
        AppLogger.info('   - stadiumManager: ${data['stadiumManager']}');
        AppLogger.info('   - clientEmail: ${data['clientEmail']}');
        AppLogger.info('   - stadeNom: ${data['stadeNom']}');
        AppLogger.info('   - statut: ${data['statut']}');
        AppLogger.info('   - Data complète: $data');
      } else {
        AppLogger.error('❌ Réservation non trouvée: $reservationId');
      }
    } catch (e) {
      AppLogger.error('❌ Erreur lors de la vérification: $e');
    }
  }

  /// Vérifier qu'un gestionnaire peut voir ses réservations
  static Future<void> checkManagerCanSeeReservation(String managerEmail) async {
    try {
      AppLogger.info('🔍 Test de récupération des réservations pour: $managerEmail');

      final reservations = await FirebaseReservationService.getManagerReservationsByEmail(managerEmail);

      AppLogger.info('📊 Résultats pour $managerEmail: ${reservations.length} réservations');

      for (var reservation in reservations) {
        AppLogger.info('   - Réservation ${reservation.id}: ${reservation.stadeNom} par ${reservation.clientNom}');
      }
    } catch (e) {
      AppLogger.error('❌ Erreur lors de la récupération: $e');
    }
  }

  /// Lister toutes les réservations dans la base de données
  static Future<void> listAllReservations() async {
    try {
      AppLogger.info('📊 Liste de toutes les réservations dans la base...');

      final querySnapshot = await _firestore.collection('reservations').get();

      AppLogger.info('Total de réservations: ${querySnapshot.docs.length}');

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        AppLogger.info('Réservation ${doc.id}:');
        AppLogger.info('   - stadiumManager: "${data['stadiumManager']}"');
        AppLogger.info('   - clientEmail: "${data['clientEmail']}"');
        AppLogger.info('   - stadeNom: "${data['stadeNom']}"');
        AppLogger.info('   - statut: "${data['statut']}"');
        AppLogger.info('   - dateCreation: ${data['dateCreation']}');
      }
    } catch (e) {
      AppLogger.error('❌ Erreur lors de la liste: $e');
    }
  }

  /// Nettoyer les réservations de test
  static Future<void> cleanupTestReservations() async {
    try {
      AppLogger.info('🧹 Nettoyage des réservations de test...');

      final querySnapshot = await _firestore
          .collection('reservations')
          .where('clientEmail', isEqualTo: 'client@test.com')
          .get();

      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
        AppLogger.info('🗑️ Réservation de test supprimée: ${doc.id}');
      }

      AppLogger.info('✅ Nettoyage terminé');
    } catch (e) {
      AppLogger.error('❌ Erreur lors du nettoyage: $e');
    }
  }
}