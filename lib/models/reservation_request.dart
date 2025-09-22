import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationRequest {
  final String id;
  final String stadeId;
  final String stadeNom;
  final String stadiumManager;
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
    required this.stadiumManager,
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
        'stadiumManager': stadiumManager,
        'clientNom': clientNom,
        'clientEmail': clientEmail,
        'dateReservation': dateReservation.toIso8601String(),
        'heureDebut': heureDebut,
        'heureFin': heureFin,
        'raison': raison,
        'statut': statut,
        'dateCreation': dateCreation.toIso8601String(),
      };

  ReservationRequest copyWith({
    String? id,
    String? stadeId,
    String? stadeNom,
    String? stadiumManager,
    String? clientNom,
    String? clientEmail,
    DateTime? dateReservation,
    String? heureDebut,
    String? heureFin,
    String? raison,
    String? statut,
    DateTime? dateCreation,
  }) {
    return ReservationRequest(
      id: id ?? this.id,
      stadeId: stadeId ?? this.stadeId,
      stadeNom: stadeNom ?? this.stadeNom,
      stadiumManager: stadiumManager ?? this.stadiumManager,
      clientNom: clientNom ?? this.clientNom,
      clientEmail: clientEmail ?? this.clientEmail,
      dateReservation: dateReservation ?? this.dateReservation,
      heureDebut: heureDebut ?? this.heureDebut,
      heureFin: heureFin ?? this.heureFin,
      raison: raison ?? this.raison,
      statut: statut ?? this.statut,
      dateCreation: dateCreation ?? this.dateCreation,
    );
  }

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
      stadiumManager: json['stadiumManager'] ?? '',
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