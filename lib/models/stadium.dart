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
      prix: (map['prix'] ?? 0).toInt(),
      type: map['type'] ?? '',
      capacite: map['capacite'] ?? '',
      disponible: map['disponible'] ?? true,
      description: map['description'] ?? '',
      gestionnaire: map['gestionnaire'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      horaires:
          Map<String, dynamic>.from(map['horaires'] ?? _defaultSchedule()),
      dateCreation: map['dateCreation'] != null
          ? (map['dateCreation'] is String
              ? DateTime.parse(map['dateCreation'])
              : (map['dateCreation'].toDate() as DateTime))
          : DateTime.now(),
      amenities: Map<String, dynamic>.from(map['amenities'] ?? {}),
    );
  }
}