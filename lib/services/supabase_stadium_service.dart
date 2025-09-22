import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stadium.dart';
import '../utils/app_logger.dart';

/// Service pour gérer les stades dans Supabase
class SupabaseStadiumService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'stadiums';

  /// Créer un nouveau stade
  static Future<String?> createStadium(Stadium stadium) async {
    try {
      final data = stadium.toMap();
      data.remove('id'); // Supabase génère l'ID automatiquement

      final response = await _client
          .from(_table)
          .insert(data)
          .select('id')
          .single();

      AppLogger.info('Stade créé avec succès: ${response['id']}');
      return response['id'].toString();
    } catch (e) {
      AppLogger.error('Erreur lors de la création du stade: $e');
      return null;
    }
  }

  /// Mettre à jour un stade existant
  static Future<bool> updateStadium(String stadiumId, Stadium stadium) async {
    try {
      final data = stadium.toMap();
      data.remove('id'); // On ne met pas à jour l'ID

      await _client
          .from(_table)
          .update(data)
          .eq('id', stadiumId);

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
      final response = await _client
          .from(_table)
          .select()
          .eq('disponible', true)
          .order('date_creation', ascending: false);

      return response.map<Stadium>((data) {
        // Convertir les clés snake_case en camelCase pour le modèle
        final convertedData = _convertFromSupabaseFormat(data);
        return Stadium.fromMap(convertedData);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des stades: $e');
      return [];
    }
  }

  /// Récupérer tous les stades d'un gestionnaire
  static Future<List<Stadium>> getStadiumsByManager(String managerEmail) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('gestionnaire', managerEmail)
          .order('date_creation', ascending: false);

      return response.map<Stadium>((data) {
        final convertedData = _convertFromSupabaseFormat(data);
        return Stadium.fromMap(convertedData);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des stades du gestionnaire: $e');
      return [];
    }
  }

  /// Récupérer un stade par son ID
  static Future<Stadium?> getStadiumById(String stadiumId) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', stadiumId)
          .single();

      final convertedData = _convertFromSupabaseFormat(response);
      return Stadium.fromMap(convertedData);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération du stade: $e');
      return null;
    }
  }

  /// Supprimer un stade (soft delete)
  static Future<bool> deleteStadium(String stadiumId) async {
    try {
      await _client
          .from(_table)
          .update({'disponible': false})
          .eq('id', stadiumId);

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
      var query = _client.from(_table).select().eq('disponible', true);

      if (quartier != null && quartier.isNotEmpty) {
        query = query.eq('quartier', quartier);
      }

      if (type != null && type.isNotEmpty) {
        query = query.eq('type', type);
      }

      if (prixMax != null) {
        query = query.lte('prix', prixMax);
      }

      if (searchText != null && searchText.isNotEmpty) {
        query = query.or('nom.ilike.%$searchText%,adresse.ilike.%$searchText%,description.ilike.%$searchText%');
      }

      final response = await query.order('date_creation', ascending: false);

      return response.map<Stadium>((data) {
        final convertedData = _convertFromSupabaseFormat(data);
        return Stadium.fromMap(convertedData);
      }).toList();
    } catch (e) {
      AppLogger.error('Erreur lors de la recherche des stades: $e');
      return [];
    }
  }

  /// Convertir les données de Supabase (snake_case) vers le format attendu (camelCase)
  static Map<String, dynamic> _convertFromSupabaseFormat(Map<String, dynamic> data) {
    return {
      'id': data['id']?.toString() ?? '',
      'nom': data['nom'] ?? '',
      'adresse': data['adresse'] ?? '',
      'quartier': data['quartier'] ?? '',
      'prix': data['prix'] ?? 0,
      'type': data['type'] ?? '',
      'capacite': data['capacite'] ?? '',
      'disponible': data['disponible'] ?? true,
      'description': data['description'] ?? '',
      'gestionnaire': data['gestionnaire'] ?? '',
      'images': (data['images'] as List?)?.cast<String>() ?? [],
      'horaires': data['horaires'] as Map<String, dynamic>? ?? {},
      'dateCreation': data['date_creation'] ?? DateTime.now().toIso8601String(),
      'amenities': data['amenities'] as Map<String, dynamic>? ?? {},
    };
  }

  /// Convertir les données vers le format Supabase (snake_case)
  static Map<String, dynamic> _convertToSupabaseFormat(Map<String, dynamic> data) {
    final converted = Map<String, dynamic>.from(data);

    // Convertir dateCreation en date_creation
    if (converted.containsKey('dateCreation')) {
      converted['date_creation'] = converted.remove('dateCreation');
    }

    return converted;
  }

  /// Obtenir les statistiques des stades
  static Future<Map<String, dynamic>> getStadiumStats() async {
    try {
      final totalResponse = await _client
          .from(_table)
          .select('*');

      final availableResponse = await _client
          .from(_table)
          .select('*')
          .eq('disponible', true);

      final typeResponse = await _client
          .from(_table)
          .select('type')
          .eq('disponible', true);

      // Compter par type
      final typeCount = <String, int>{};
      for (final row in typeResponse) {
        final type = row['type'] as String;
        typeCount[type] = (typeCount[type] ?? 0) + 1;
      }

      return {
        'total': totalResponse.length,
        'disponibles': availableResponse.length,
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
}