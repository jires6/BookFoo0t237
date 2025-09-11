/// Configuration pour les services d'envoi d'emails et SMS
/// 
/// IMPORTANT: NE COMMITEZ JAMAIS VOS VRAIES CLÉS API!
/// Utilisez des variables d'environnement ou Firebase Remote Config en production.

class NotificationConfig {
  // =================
  // CONFIGURATION EMAIL SMTP
  // =================
  
  /// Pour utiliser Gmail:
  /// 1. Activez l'authentification à 2 facteurs sur votre compte Gmail
  /// 2. Générez un "Mot de passe d'application" dans les paramètres Google
  /// 3. Utilisez ce mot de passe (pas votre mot de passe Gmail normal)
  static const String gmailUsername = 'bookfoot237@gmail.com';
  static const String gmailAppPassword = 'urvy gpjp efoe qnzq';
  
  /// Alternative: Utilisez des services email professionnels
  /// SendGrid (gratuit jusqu'à 100 emails/jour)
  static const String sendGridApiKey = 'SG.votre_cle_sendgrid';
  
  /// Mailgun (gratuit jusqu'à 5000 emails/mois)
  static const String mailgunApiKey = 'votre_cle_mailgun';
  static const String mailgunDomain = 'votre_domaine.mailgun.org';
  
  // =================
  // CONFIGURATION SMS
  // =================
  
  /// Twilio (service SMS payant mais fiable)
  static const String twilioAccountSid = 'votre_account_sid';
  static const String twilioAuthToken = 'votre_auth_token';
  static const String twilioPhoneNumber = '+1234567890'; // Numéro Twilio
  
  /// TextLocal (service SMS gratuit/payant)
  static const String textLocalApiKey = 'votre_cle_textlocal';
  
  /// Orange SMS API (pour le Cameroun)
  static const String orangeSmsApiKey = 'votre_cle_orange';
  static const String orangeSmsUrl = 'https://api.orange.com/smsmessaging/v1/';
  
  /// MTN SMS API (pour le Cameroun)
  static const String mtnSmsApiKey = 'votre_cle_mtn';
  static const String mtnSmsUrl = 'https://api.mtn.cm/sms/';
  
  // =================
  // CONFIGURATION EMAILJS (Gratuit)
  // =================
  
  /// EmailJS (service gratuit, limité mais facile à configurer)
  /// 1. Créez un compte sur https://emailjs.com
  /// 2. Créez un service email (Gmail, Outlook, etc.)
  /// 3. Créez un template
  /// 4. Récupérez vos IDs
  static const String emailJsServiceId = 'votre_service_id';
  static const String emailJsTemplateId = 'votre_template_id';
  static const String emailJsUserId = 'votre_user_id';
  
  // =================
  // MÉTHODES D'AIDE
  // =================
  
  /// Retourne true si la configuration Gmail est prête
  static bool get isGmailConfigured {
    return gmailUsername.isNotEmpty && 
           gmailUsername != 'votre_email@gmail.com' &&
           gmailAppPassword.isNotEmpty && 
           gmailAppPassword != 'votre_mot_de_passe_app_16_caracteres';
  }
  
  /// Retourne true si EmailJS est configuré
  static bool get isEmailJsConfigured {
    return emailJsServiceId.isNotEmpty && 
           emailJsServiceId != 'votre_service_id' &&
           emailJsTemplateId.isNotEmpty &&
           emailJsUserId.isNotEmpty;
  }
  
  /// Retourne true si Twilio SMS est configuré
  static bool get isTwilioConfigured {
    return twilioAccountSid.isNotEmpty && 
           twilioAccountSid != 'votre_account_sid' &&
           twilioAuthToken.isNotEmpty &&
           twilioPhoneNumber.isNotEmpty;
  }
}