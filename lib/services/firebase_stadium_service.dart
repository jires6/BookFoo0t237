import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/stadium.dart';
import '../utils/app_logger.dart';

/// Service Firebase pour gérer les stades
class FirebaseStadiumService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _collection = 'stadiums';

  /// Créer un nouveau stade
  static Future<String?> createStadium(Stadium stadium) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'Utilisateur non connecté';
      }

      final data = stadium.toMap();
      data.remove('id'); // Firestore génère l'ID automatiquement
      data['gestionnaire'] = user.email; // S'assurer que le gestionnaire est l'utilisateur connecté
      data['dateCreation'] = FieldValue.serverTimestamp();

      final docRef = await _firestore.collection(_collection).add(data);

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
      final user = _auth.currentUser;
      if (user == null) {
        throw 'Utilisateur non connecté';
      }

      final data = stadium.toMap();
      data.remove('id'); // On ne met pas à jour l'ID
      data['gestionnaire'] = user.email; // S'assurer que le gestionnaire est correct
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collection).doc(stadiumId).update(data);

      AppLogger.info('Stade mis à jour avec succès: $stadiumId');
      return true;
    } catch (e) {
      AppLogger.error('Erreur lors de la mise à jour du stade: $e');
      return false;
    }
  }

  /// Récupérer tous les stades disponibles
  static Future<List<Stadium>> getAllStadiums() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('disponible', isEqualTo: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Stadium.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des stades: $e');
      return [];
    }
  }

  /// Récupérer tous les stades d'un gestionnaire
  static Future<List<Stadium>> getStadiumsByManager(String managerEmail) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('gestionnaire', isEqualTo: managerEmail)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Stadium.fromMap(data);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des stades du gestionnaire: $e');
      return [];
    }
  }

  /// Récupérer un stade par son ID
  static Future<Stadium?> getStadiumById(String stadiumId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(stadiumId).get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return Stadium.fromMap(data);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération du stade: $e');
      return null;
    }
  }

  /// Supprimer un stade (soft delete)
  static Future<bool> deleteStadium(String stadiumId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'Utilisateur non connecté';
      }

      await _firestore.collection(_collection).doc(stadiumId).update({
        'disponible': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Stade supprimé avec succès: $stadiumId');
      return true;
    } catch (e) {
      AppLogger.error('Erreur lors de la suppression du stade: $e');
      return false;
    }
  }

  /// Rechercher des stades par critères
  static Future<List<Stadium>> searchStadiums({
    String? quartier,
    String? type,
    int? prixMax,
    String? searchText,
  }) async {
    try {
      Query query = _firestore.collection(_collection).where('disponible', isEqualTo: true);

      if (quartier != null && quartier.isNotEmpty) {
        query = query.where('quartier', isEqualTo: quartier);
      }

      if (type != null && type.isNotEmpty) {
        query = query.where('type', isEqualTo: type);
      }

      if (prixMax != null) {
        query = query.where('prix', isLessThanOrEqualTo: prixMax);
      }

      final querySnapshot = await query.orderBy('dateCreation', descending: true).get();

      List<Stadium> stadiums = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Stadium.fromMap(data);
      }).toList();

      // Filtrage par texte côté client (Firestore ne supporte pas les recherches textuelles complexes)
      if (searchText != null && searchText.isNotEmpty) {
        final searchLower = searchText.toLowerCase();
        stadiums = stadiums.where((stadium) {
          return stadium.nom.toLowerCase().contains(searchLower) ||
                 stadium.adresse.toLowerCase().contains(searchLower) ||
                 stadium.description.toLowerCase().contains(searchLower);
        }).toList();
      }

      return stadiums;
    } catch (e) {
      AppLogger.error('Erreur lors de la recherche des stades: $e');
      return [];
    }
  }

  /// Obtenir les statistiques des stades
  static Future<Map<String, dynamic>> getStadiumStats() async {
    try {
      final totalSnapshot = await _firestore.collection(_collection).get();
      final availableSnapshot = await _firestore
          .collection(_collection)
          .where('disponible', isEqualTo: true)
          .get();

      // Compter par type
      final typeCount = <String, int>{};
      for (final doc in availableSnapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'Autre';
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }

      return {
        'total': totalSnapshot.docs.length,
        'disponibles': availableSnapshot.docs.length,
        'parType': typeCount,
      };
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des statistiques: $e');
      return {
        'total': 0,
        'disponibles': 0,
        'parType': <String, int>{},
      };
    }
  }

  /// Vérifier si l'utilisateur actuel peut modifier ce stade
  static Future<bool> canManageStadium(String stadiumId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection(_collection).doc(stadiumId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return data['gestionnaire'] == user.email;
    } catch (e) {
      AppLogger.error('Erreur lors de la vérification des permissions: $e');
      return false;
    }
  }
}