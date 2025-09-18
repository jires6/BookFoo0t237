import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/notification_config.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  // Configuration depuis le fichier config
  static const String _smtpHost = 'smtp.gmail.com';
  static const int _smtpPort = 587;
  static const int _smtpPortSSL = 465;

  /// Génère un code OTP aléatoire à 6 chiffres
  String _generateOtpCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Envoie un email OTP réel avec plusieurs méthodes
  Future<String?> sendEmailOtp(String email) async {
    final otpCode = _generateOtpCode();

    // Stocker le code pour vérification ultérieure
    _storeOtpCode(email, otpCode);

    // Essayer Gmail SMTP si configuré
    if (NotificationConfig.isGmailConfigured) {
      final result = await _sendEmailViaGmail(email, otpCode);
      if (result) return otpCode;
    }

    // Essayer EmailJS si configuré
    if (NotificationConfig.isEmailJsConfigured) {
      final result = await _sendEmailViaEmailJS(email, otpCode);
      if (result) return otpCode;
    }

    // Aucun service configuré
    print('Aucun service email configuré. Vérifiez notification_config.dart');
    return null;
  }
  
  /// Envoi via Gmail SMTP
  Future<bool> _sendEmailViaGmail(String email, String otpCode) async {
    try {
      // Configuration SMTP adaptée pour différents fournisseurs
      final bool isAppleEmail = email.toLowerCase().contains('@icloud.com') ||
                               email.toLowerCase().contains('@me.com') ||
                               email.toLowerCase().contains('@mac.com');

      // Essayer d'abord avec STARTTLS (port 587), puis SSL (port 465) si échec
      SmtpServer smtpServer;

      if (isAppleEmail) {
        // Pour Apple, utiliser SSL direct (port 465) car plus fiable
        smtpServer = SmtpServer(
          _smtpHost,
          port: _smtpPortSSL,
          username: NotificationConfig.gmailUsername,
          password: NotificationConfig.gmailAppPassword,
          allowInsecure: false,
          ssl: true,
          ignoreBadCertificate: false,
        );
        print('📧 Configuration SSL directe pour adresse Apple: $email');
      } else {
        // Pour autres fournisseurs, utiliser STARTTLS (port 587)
        smtpServer = SmtpServer(
          _smtpHost,
          port: _smtpPort,
          username: NotificationConfig.gmailUsername,
          password: NotificationConfig.gmailAppPassword,
          allowInsecure: false,
          ssl: false, // STARTTLS
          ignoreBadCertificate: false,
        );
        print('📧 Configuration STARTTLS pour: $email');
      }

      final message = Message()
        ..from = Address(NotificationConfig.gmailUsername, 'BookFoot237')
        ..recipients.add(email);

      // Configuration spéciale pour les adresses Apple
      if (isAppleEmail) {
        message.subject = '🔐 Votre code BookFoot237: $otpCode';
        // Email plus simple pour éviter les filtres Apple
        message.text = '''
Bonjour,

Votre code de vérification BookFoot237: $otpCode

Ce code expire dans 5 minutes.
Ne le partagez avec personne.

Cordialement,
L'équipe BookFoot237
''';
        message.html = '''
          <div style="font-family: system-ui, -apple-system, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #1E88E5; text-align: center;">⚽ BookFoot237</h2>
            <p>Bonjour,</p>
            <p>Votre code de vérification:</p>
            <div style="background: #f8f9fa; border: 2px solid #1E88E5; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; color: #1E88E5; margin: 20px 0;">
              $otpCode
            </div>
            <p style="font-size: 12px; color: #666;">Ce code expire dans 5 minutes.</p>
            <p style="font-size: 12px; color: #666;">BookFoot237 - Yaoundé</p>
          </div>
        ''';
      } else {
        message.subject = 'Code de vérification BookFoot237 - $otpCode';
        message.html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background-color: #1E88E5; padding: 20px; text-align: center;">
              <h1 style="color: white; margin: 0;">⚽ BookFoot237</h1>
            </div>
            <div style="padding: 30px; background-color: #f5f5f5;">
              <h2 style="color: #333;">Code de vérification</h2>
              <p style="font-size: 16px; color: #666;">Bonjour,</p>
              <p style="font-size: 16px; color: #666;">
                Voici votre code de vérification pour créer votre compte BookFoot237:
              </p>
              <div style="background-color: #1E88E5; color: white; padding: 20px; text-align: center; font-size: 32px; font-weight: bold; margin: 20px 0; border-radius: 8px;">
                $otpCode
              </div>
              <p style="font-size: 14px; color: #999;">
                Ce code expire dans 5 minutes. Ne le partagez avec personne.
              </p>
              <p style="font-size: 14px; color: #999;">
                Si vous n'avez pas demandé ce code, ignorez cet email.
              </p>
            </div>
            <div style="background-color: #333; padding: 15px; text-align: center;">
              <p style="color: #ccc; margin: 0; font-size: 12px;">
                BookFoot237 - Réservation de terrains de football à Yaoundé
              </p>
            </div>
          </div>
        ''';
      }

      final sendReport = await send(message, smtpServer);
      print('Email Gmail envoyé: ${sendReport.toString()}');
      return true;
    } catch (e) {
      print('Erreur envoi Gmail: $e');
      return false;
    }
  }
  
  /// Envoi via EmailJS (service gratuit)
  Future<bool> _sendEmailViaEmailJS(String email, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': NotificationConfig.emailJsServiceId,
          'template_id': NotificationConfig.emailJsTemplateId,
          'user_id': NotificationConfig.emailJsUserId,
          'template_params': {
            'to_email': email,
            'otp_code': otpCode,
            'app_name': 'BookFoot237',
            'message': 'Votre code de vérification BookFoot237 est: $otpCode',
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Email EmailJS envoyé à $email');
        return true;
      } else {
        print('Erreur EmailJS: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Erreur service EmailJS: $e');
      return false;
    }
  }

  /// Envoie un SMS OTP réel avec plusieurs méthodes
  Future<String?> sendSmsOtp(String phoneNumber) async {
    final otpCode = _generateOtpCode();
    
    // Essayer Twilio si configuré
    if (NotificationConfig.isTwilioConfigured) {
      final result = await _sendSmsViaTwilio(phoneNumber, otpCode);
      if (result) return otpCode;
    }
    
    // Fallback: utiliser Firebase Phone Auth
    print('Aucun service SMS configuré. Utilisez Firebase Phone Auth.');
    return null;
  }
  
  /// Envoi SMS via Twilio
  Future<bool> _sendSmsViaTwilio(String phoneNumber, String otpCode) async {
    try {
      final message = 'Votre code BookFoot237: $otpCode. Valide 5 min. Ne le partagez pas.';
      
      final response = await http.post(
        Uri.parse('https://api.twilio.com/2010-04-01/Accounts/${NotificationConfig.twilioAccountSid}/Messages.json'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Basic ${base64Encode(utf8.encode('${NotificationConfig.twilioAccountSid}:${NotificationConfig.twilioAuthToken}'))}',
        },
        body: {
          'From': NotificationConfig.twilioPhoneNumber,
          'To': phoneNumber,
          'Body': message,
        },
      );

      if (response.statusCode == 201) {
        print('SMS Twilio envoyé à $phoneNumber');
        return true;
      } else {
        print('Erreur Twilio: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Erreur envoi Twilio: $e');
      return false;
    }
  }

  /// Alternative: Utilise les services gratuits ou intégrés
  Future<String?> sendEmailOtpFallback(String email) async {
    try {
      // Cette méthode utilise un service email gratuit ou une API simple
      final otpCode = _generateOtpCode();
      
      // Utilisation d'EmailJS ou service similaire (gratuit)
      // Vous devez configurer un compte sur EmailJS.com
      const serviceId = 'votre_service_id';
      const templateId = 'votre_template_id';
      const userId = 'votre_user_id';
      
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': userId,
          'template_params': {
            'to_email': email,
            'otp_code': otpCode,
            'app_name': 'BookFoot237',
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Email OTP envoyé via EmailJS à $email');
        return otpCode;
      } else {
        print('Erreur EmailJS: ${response.statusCode}');
      }
      
      return null;
    } catch (e) {
      print('Erreur service email fallback: $e');
      return null;
    }
  }

  /// Utilise Firebase Auth pour SMS (solution recommandée)
  Future<String?> sendSmsOtpViaFirebase(String phoneNumber, Function onCodeSent) async {
    try {
      // Cette méthode utilise Firebase Phone Auth qui envoie les vrais SMS
      // Firebase gère automatiquement l'envoi des SMS dans la plupart des pays
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {
          // Auto-vérification réussie
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Erreur vérification téléphone: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
          print('Code SMS envoyé à $phoneNumber via Firebase');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Timeout
        },
      );

      return 'firebase_handled'; // Indique que Firebase gère le processus
    } catch (e) {
      print('Erreur Firebase SMS: $e');
      return null;
    }
  }

  /// Vérifie un code OTP
  static final Map<String, String> _otpCodes = {};

  /// Stocke temporairement le code OTP pour vérification
  void _storeOtpCode(String email, String code) {
    _otpCodes[email] = code;
    // Supprimer le code après 5 minutes
    Timer(const Duration(minutes: 5), () {
      _otpCodes.remove(email);
    });
  }

  /// Vérifie si le code OTP est correct
  bool verifyOtpCode(String email, String enteredCode) {
    final storedCode = _otpCodes[email];
    if (storedCode != null && storedCode == enteredCode) {
      _otpCodes.remove(email);
      return true;
    }
    return false;
  }
}