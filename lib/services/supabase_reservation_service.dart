import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reservation_request.dart';
import '../utils/app_logger.dart';

/// Service pour gérer les réservations dans Supabase
class SupabaseReservationService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'reservations';

  /// Créer une nouvelle réservation
  static Future<String?> createReservation(ReservationRequest reservation) async {
    try {
      final data = reservation.toJson();
      data.remove('id'); // Supabase génère l'ID automatiquement

      // Convertir les dates au format compatible Supabase
      data['date_reservation'] = data.remove('dateReservation');
      data['date_creation'] = data.remove('dateCreation');
      data['stade_id'] = data.remove('stadeId');
      data['stade_nom'] = data.remove('stadeNom');
      data['client_nom'] = data.remove('clientNom');
      data['client_email'] = data.remove('clientEmail');
      data['heure_debut'] = data.remove('heureDebut');
      data['heure_fin'] = data.remove('heureFin');

      final response = await _client
          .from(_table)
          .insert(data)
          .select('id')
          .single();

      AppLogger.info('Réservation créée avec succès: ${response['id']}');
      return response['id'].toString();
    } catch (e) {
      AppLogger.error('Erreur lors de la création de la réservation: $e');
      return null;
    }
  }

  /// Mettre à jour le statut d'une réservation
  static Future<bool> updateReservationStatus(String reservationId, String newStatus) async {
    try {
      await _client
          .from(_table)
          .update({'statut': newStatus})
          .eq('id', reservationId);

      AppLogger.info('Statut de réservation mis à jour: $reservationId -> $newStatus');
      return true;
    } catch (e) {
      AppLogger.error('Erreur lors de la mise à jour du statut: $e');
      return false;
    }
  }

  /// Récupérer toutes les réservations d'un client
  static Future<List<ReservationRequest>> getReservationsByClient(String clientEmail) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('client_email', clientEmail)
          .order('date_creation', ascending: false);

      return response.map<ReservationRequest>((data) {
        final convertedData = _convertFromSupabaseFormat(data);
        return ReservationRequest.fromJson(convertedData);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des réservations du client: $e');
      return [];
    }
  }

  /// Récupérer toutes les réservations pour un gestionnaire de stade
  static Future<List<ReservationRequest>> getReservationsByManager(String managerEmail) async {
    try {
      // Récupérer d'abord les stades du gestionnaire
      final stadiumResponse = await _client
          .from('stadiums')
          .select('id')
          .eq('gestionnaire', managerEmail);

      final stadiumIds = stadiumResponse.map((stadium) => stadium['id']).toList();

      if (stadiumIds.isEmpty) {
        return [];
      }

      final response = await _client
          .from(_table)
          .select()
          .in_('stade_id', stadiumIds)
          .order('date_creation', ascending: false);

      return response.map<ReservationRequest>((data) {
        final convertedData = _convertFromSupabaseFormat(data);
        return ReservationRequest.fromJson(convertedData);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des réservations du gestionnaire: $e');
      return [];
    }
  }

  /// Récupérer les réservations d'un stade spécifique
  static Future<List<ReservationRequest>> getReservationsByStadium(String stadiumId) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('stade_id', stadiumId)
          .order('date_reservation', ascending: true);

      return response.map<ReservationRequest>((data) {
        final convertedData = _convertFromSupabaseFormat(data);
        return ReservationRequest.fromJson(convertedData);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des réservations du stade: $e');
      return [];
    }
  }

  /// Récupérer une réservation par son ID
  static Future<ReservationRequest?> getReservationById(String reservationId) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', reservationId)
          .single();

      final convertedData = _convertFromSupabaseFormat(response);
      return ReservationRequest.fromJson(convertedData);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération de la réservation: $e');
      return null;
    }
  }

  /// Supprimer une réservation
  static Future<bool> deleteReservation(String reservationId) async {
    try {
      await _client
          .from(_table)
          .delete()
          .eq('id', reservationId);

      AppLogger.info('Réservation supprimée avec succès: $reservationId');
      return true;
    } catch (e) {
      AppLogger.error('Erreur lors de la suppression de la réservation: $e');
      return false;
    }
  }

  /// Vérifier les conflits de réservation
  static Future<bool> hasConflict({
    required String stadiumId,
    required DateTime date,
    required String heureDebut,
    required String heureFin,
    String? excludeReservationId,
  }) async {
    try {
      var query = _client
          .from(_table)
          .select()
          .eq('stade_id', stadiumId)
          .eq('date_reservation', date.toIso8601String().split('T')[0])
          .in_('statut', ['en_attente', 'confirmee']);

      if (excludeReservationId != null) {
        query = query.neq('id', excludeReservationId);
      }

      final response = await query;

      // Vérifier les conflits d'horaires
      for (final reservation in response) {
        final existingDebut = reservation['heure_debut'] as String;
        final existingFin = reservation['heure_fin'] as String;

        // Convertir les heures en minutes pour faciliter la comparaison
        final nouveauDebutMinutes = _timeToMinutes(heureDebut);
        final nouveauFinMinutes = _timeToMinutes(heureFin);
        final existingDebutMinutes = _timeToMinutes(existingDebut);
        final existingFinMinutes = _timeToMinutes(existingFin);

        // Vérifier s'il y a chevauchement
        if (nouveauDebutMinutes < existingFinMinutes && nouveauFinMinutes > existingDebutMinutes) {
          return true; // Conflit détecté
        }
      }

      return false; // Pas de conflit
    } catch (e) {
      AppLogger.error('Erreur lors de la vérification des conflits: $e');
      return true; // En cas d'erreur, considérer qu'il y a conflit par sécurité
    }
  }

  /// Récupérer les statistiques de réservations
  static Future<Map<String, dynamic>> getReservationStats() async {
    try {
      final totalResponse = await _client
          .from(_table)
          .select('*');

      final statusResponse = await _client
          .from(_table)
          .select('statut');

      // Compter par statut
      final statusCount = <String, int>{};
      for (final row in statusResponse) {
        final status = row['statut'] as String;
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      // Réservations du mois en cours
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final monthlyResponse = await _client
          .from(_table)
          .select('*')
          .gte('date_creation', startOfMonth.toIso8601String());

      return {
        'total': totalResponse.length,
        'parStatut': statusCount,
        'ceMois': monthlyResponse.length,
      };
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des statistiques: $e');
      return {
        'total': 0,
        'parStatut': <String, int>{},
        'ceMois': 0,
      };
    }
  }

  /// Convertir les données de Supabase vers le format attendu
  static Map<String, dynamic> _convertFromSupabaseFormat(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString() ?? '',
      'stadeId': data['stade_id'] ?? '',
      'stadeNom': data['stade_nom'] ?? '',
      'clientNom': data['client_nom'] ?? '',
      'clientEmail': data['client_email'] ?? '',
      'dateReservation': data['date_reservation'] ?? DateTime.now().toIso8601String(),
      'heureDebut': data['heure_debut'] ?? '',
      'heureFin': data['heure_fin'] ?? '',
      'raison': data['raison'] ?? '',
      'statut': data['statut'] ?? 'en_attente',
      'dateCreation': data['date_creation'] ?? DateTime.now().toIso8601String(),
    };
  }

  /// Convertir une heure (HH:MM) en minutes depuis minuit
  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return 0;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    return hours * 60 + minutes;
  }

  /// Rechercher des réservations par critères
  static Future<List<ReservationRequest>> searchReservations({
    String? clientEmail,
    String? stadiumId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client.from(_table).select();

      if (clientEmail != null && clientEmail.isNotEmpty) {
        query = query.eq('client_email', clientEmail);
      }

      if (stadiumId != null && stadiumId.isNotEmpty) {
        query = query.eq('stade_id', stadiumId);
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('statut', status);
      }

      if (startDate != null) {
        query = query.gte('date_reservation', startDate.toIso8601String().split('T')[0]);
      }

      if (endDate != null) {
        query = query.lte('date_reservation', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('date_creation', ascending: false);

      return response.map<ReservationRequest>((data) {
        final convertedData = _convertFromSupabaseFormat(data);
        return ReservationRequest.fromJson(convertedData);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la recherche des réservations: $e');
      return [];
    }
  }
}