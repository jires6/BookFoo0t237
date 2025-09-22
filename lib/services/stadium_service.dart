import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stadium.dart';
import '../utils/app_logger.dart';

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