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