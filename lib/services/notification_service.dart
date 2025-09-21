import 'dart:convert';
import 'dart:io';
import 'dart:math';
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

  /// Génère un code OTP aléatoire à 6 chiffres
  String _generateOtpCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Envoie un email OTP réel avec plusieurs méthodes
  Future<String?> sendEmailOtp(String email) async {
    final otpCode = _generateOtpCode();
    
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
      final smtpServer = SmtpServer(
        _smtpHost,
        port: _smtpPort,
        username: NotificationConfig.gmailUsername,
        password: NotificationConfig.gmailAppPassword,
        allowInsecure: false,
        ssl: false,
        ignoreBadCertificate: false,
      );

      final message = Message()
        ..from = Address(NotificationConfig.gmailUsername, 'BookFoot237')
        ..recipients.add(email)
        ..subject = 'Code de vérification BookFoot237 - $otpCode'
        ..html = '''
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

  /// Envoie un email de statut de réservation (confirmation/rejet)
  Future<bool> sendReservationStatusEmail({
    required String clientEmail,
    required String clientName,
    required String stadeNom,
    required String dateReservation,
    required String heureDebut,
    required String heureFin,
    required String raison,
    required bool isAccepted,
  }) async {
    try {
      print('📧 Envoi email de statut réservation à $clientEmail');

      // Utiliser la même configuration Gmail que pour les OTP
      if (!NotificationConfig.isGmailConfigured) {
        print('❌ Configuration Gmail manquante');
        return false;
      }

      final smtpServer = SmtpServer(
        'smtp.gmail.com',
        port: 587,
        username: NotificationConfig.gmailUsername,
        password: NotificationConfig.gmailAppPassword,
        allowInsecure: false,
        ssl: false,
        ignoreBadCertificate: false,
      );

      String subject;
      String htmlContent;

      if (isAccepted) {
        subject = '✅ Votre réservation a été confirmée - BookFoot237';
        htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #4CAF50; color: white; padding: 20px; text-align: center;">
            <h1>🎉 Réservation Confirmée !</h1>
          </div>

          <div style="padding: 20px; background-color: #f5f5f5;">
            <h2>Bonjour $clientName,</h2>

            <p>Excellente nouvelle ! Votre demande de réservation a été <strong>acceptée</strong> par le gestionnaire.</p>

            <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <h3>📋 Détails de votre réservation :</h3>
              <ul style="line-height: 1.6;">
                <li><strong>Stade :</strong> $stadeNom</li>
                <li><strong>Date :</strong> $dateReservation</li>
                <li><strong>Horaire :</strong> $heureDebut - $heureFin</li>
                <li><strong>Raison :</strong> $raison</li>
              </ul>
            </div>

            <div style="background-color: #e8f5e8; padding: 15px; border-radius: 8px; border-left: 4px solid #4CAF50;">
              <p><strong>⚠️ Important :</strong> Votre réservation est maintenant confirmée. Veuillez vous présenter à l'heure prévue.</p>
            </div>

            <p>Merci d'avoir choisi BookFoot237 pour vos réservations de stades !</p>

            <div style="text-align: center; margin-top: 30px;">
              <p style="color: #666;">L'équipe BookFoot237<br>
              📧 contact@bookfoot237.cm | 📱 +237 6XX XXX XXX</p>
            </div>
          </div>
        </div>
        ''';
      } else {
        subject = '❌ Votre réservation a été refusée - BookFoot237';
        htmlContent = '''
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background-color: #f44336; color: white; padding: 20px; text-align: center;">
            <h1>😔 Réservation Non Confirmée</h1>
          </div>

          <div style="padding: 20px; background-color: #f5f5f5;">
            <h2>Bonjour $clientName,</h2>

            <p>Nous regrettons de vous informer que votre demande de réservation a été <strong>refusée</strong> par le gestionnaire.</p>

            <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <h3>📋 Détails de la demande :</h3>
              <ul style="line-height: 1.6;">
                <li><strong>Stade :</strong> $stadeNom</li>
                <li><strong>Date :</strong> $dateReservation</li>
                <li><strong>Horaire :</strong> $heureDebut - $heureFin</li>
                <li><strong>Raison :</strong> $raison</li>
              </ul>
            </div>

            <div style="background-color: #fff3cd; padding: 15px; border-radius: 8px; border-left: 4px solid #ffc107;">
              <p><strong>💡 Suggestion :</strong> Le créneau pourrait être déjà réservé ou indisponible. N'hésitez pas à faire une nouvelle demande pour d'autres créneaux.</p>
            </div>

            <p>Merci de votre compréhension et à bientôt sur BookFoot237 !</p>

            <div style="text-align: center; margin-top: 30px;">
              <p style="color: #666;">L'équipe BookFoot237<br>
              📧 contact@bookfoot237.cm | 📱 +237 6XX XXX XXX</p>
            </div>
          </div>
        </div>
        ''';
      }

      final message = Message()
        ..from = Address(NotificationConfig.gmailUsername, 'BookFoot237')
        ..recipients.add(clientEmail)
        ..subject = subject
        ..html = htmlContent;

      final sendReport = await send(message, smtpServer);
      print('✅ Email de statut envoyé avec succès: ${sendReport.toString()}');
      return true;

    } catch (e) {
      print('❌ Erreur envoi email de statut: $e');
      return false;
    }
  }

  /// Envoie un email de notification au gestionnaire pour une nouvelle demande de réservation
  Future<bool> sendNewReservationNotificationToManager({
    required String managerEmail,
    required String clientName,
    required String clientEmail,
    required String stadeNom,
    required String dateReservation,
    required String heureDebut,
    required String heureFin,
    required String raison,
  }) async {
    try {
      print('📧 Envoi notification nouvelle demande au gestionnaire: $managerEmail');
      print('📧 Depuis: ${NotificationConfig.gmailUsername}');
      print('📧 Configuration Gmail active: ${NotificationConfig.isGmailConfigured}');

      // Utiliser la même configuration Gmail
      if (!NotificationConfig.isGmailConfigured) {
        print('❌ Configuration Gmail manquante');
        return false;
      }

      // Configuration SMTP robuste pour tous les domaines avec sécurité renforcée
      final smtpServer = SmtpServer(
        'smtp.gmail.com',
        port: 587,
        username: NotificationConfig.gmailUsername,
        password: NotificationConfig.gmailAppPassword,
        allowInsecure: false,
        ssl: false,
        ignoreBadCertificate: false,
      );

      final subject = '🔔 Nouvelle demande de réservation - $stadeNom - BookFoot237';
      final htmlContent = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background-color: #2196F3; color: white; padding: 20px; text-align: center;">
          <h1>📋 Nouvelle Demande de Réservation</h1>
        </div>

        <div style="padding: 20px; background-color: #f5f5f5;">
          <h2>Bonjour,</h2>

          <p>Vous avez reçu une nouvelle demande de réservation pour votre stade <strong>$stadeNom</strong>.</p>

          <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #2196F3;">
            <h3>👤 Informations du client :</h3>
            <ul style="line-height: 1.6;">
              <li><strong>Nom :</strong> $clientName</li>
              <li><strong>Email :</strong> $clientEmail</li>
            </ul>
          </div>

          <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h3>📋 Détails de la demande :</h3>
            <ul style="line-height: 1.6;">
              <li><strong>Stade :</strong> $stadeNom</li>
              <li><strong>Date :</strong> $dateReservation</li>
              <li><strong>Horaire :</strong> $heureDebut - $heureFin</li>
              <li><strong>Raison :</strong> $raison</li>
            </ul>
          </div>

          <div style="background-color: #e3f2fd; padding: 15px; border-radius: 8px; border-left: 4px solid #2196F3;">
            <p><strong>⚡ Action requise :</strong> Connectez-vous à l'application BookFoot237 pour accepter ou refuser cette demande.</p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <div style="background-color: #2196F3; color: white; padding: 15px; border-radius: 8px; display: inline-block;">
              <p style="margin: 0; font-weight: bold;">📱 Ouvrez l'app BookFoot237</p>
              <p style="margin: 5px 0 0 0; font-size: 14px;">Section Gestionnaire → Demandes en attente</p>
            </div>
          </div>

          <p>Le client attend votre réponse. Une notification lui sera automatiquement envoyée dès que vous prendrez une décision.</p>

          <div style="text-align: center; margin-top: 30px;">
            <p style="color: #666;">L'équipe BookFoot237<br>
            📧 contact@bookfoot237.cm | 📱 +237 6XX XXX XXX</p>
          </div>
        </div>
      </div>
      ''';

      // Validation et nettoyage de l'adresse email du destinataire
      String cleanManagerEmail = managerEmail.trim().toLowerCase();
      print('📧 Email destinataire nettoyé: $cleanManagerEmail');

      final message = Message()
        ..from = Address(NotificationConfig.gmailUsername, 'BookFoot237')
        ..recipients.add(cleanManagerEmail)
        ..subject = subject
        ..html = htmlContent
        // Ajouter des en-têtes pour améliorer la délivrabilité
        ..headers = {
          'X-Priority': '1',
          'X-MSMail-Priority': 'High',
          'Importance': 'high',
          'Reply-To': NotificationConfig.gmailUsername,
        };

      print('📧 Tentative d\'envoi email vers: $cleanManagerEmail');
      print('📧 Sujet: $subject');

      final sendReport = await send(message, smtpServer);
      print('✅ Email de notification gestionnaire envoyé avec succès: ${sendReport.toString()}');
      print('✅ Rapport détaillé: ${sendReport.mail}');
      return true;

    } catch (e, stackTrace) {
      print('❌ Erreur envoi email notification gestionnaire: $e');
      print('❌ Stack trace: $stackTrace');

      // Tenter de déterminer le type d'erreur
      if (e.toString().contains('authentication') || e.toString().contains('username') || e.toString().contains('password')) {
        print('❌ Erreur d\'authentification Gmail - Vérifiez les identifiants');
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        print('❌ Erreur de connexion réseau');
      } else if (e.toString().contains('smtp')) {
        print('❌ Erreur SMTP serveur');
      }

      return false;
    }
  }

  /// Envoie un email de notification au gestionnaire pour une annulation de réservation
  Future<bool> sendCancellationNotificationToManager({
    required String managerEmail,
    required String clientName,
    required String clientEmail,
    required String stadeNom,
    required String dateReservation,
    required String heureDebut,
    required String heureFin,
    required String raison,
  }) async {
    try {
      print('📧 Envoi email annulation gestionnaire à: $managerEmail');

      final smtpServer = gmail(
        NotificationConfig.gmailUsername,
        NotificationConfig.gmailAppPassword,
      );

      final subject = '❌ Annulation de réservation - $stadeNom';

      final htmlContent = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #ff7043 0%, #ff5722 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
          <h1 style="color: white; margin: 0; font-size: 28px;">📋 BookFoot237</h1>
          <p style="color: white; margin: 10px 0 0 0; font-size: 16px;">Annulation de réservation</p>
        </div>

        <div style="background-color: #f5f5f5; padding: 30px; border-radius: 0 0 10px 10px;">
          <div style="background-color: #ffcdd2; padding: 15px; border-radius: 8px; border-left: 4px solid #f44336; margin-bottom: 20px;">
            <h2 style="color: #d32f2f; margin: 0 0 10px 0;">❌ Réservation annulée</h2>
            <p style="margin: 0; color: #666;">Un client a annulé sa réservation confirmée</p>
          </div>

          <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h3>👤 Informations client :</h3>
            <ul style="line-height: 1.6;">
              <li><strong>Nom :</strong> $clientName</li>
              <li><strong>Email :</strong> $clientEmail</li>
            </ul>
          </div>

          <div style="background-color: white; padding: 15px; border-radius: 8px; margin: 20px 0;">
            <h3>📋 Détails de la réservation annulée :</h3>
            <ul style="line-height: 1.6;">
              <li><strong>Stade :</strong> $stadeNom</li>
              <li><strong>Date :</strong> $dateReservation</li>
              <li><strong>Horaire :</strong> $heureDebut - $heureFin</li>
              <li><strong>Raison initiale :</strong> $raison</li>
            </ul>
          </div>

          <div style="background-color: #fff3e0; padding: 15px; border-radius: 8px; border-left: 4px solid #ff9800;">
            <p><strong>📅 Créneaux libéré :</strong> Le créneau horaire est maintenant disponible pour d'autres réservations.</p>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <div style="background-color: #ff7043; color: white; padding: 15px; border-radius: 8px; display: inline-block;">
              <p style="margin: 0; font-weight: bold;">📱 Gérez vos réservations</p>
              <p style="margin: 5px 0 0 0; font-size: 14px;">Application BookFoot237 → Section Gestionnaire</p>
            </div>
          </div>

          <div style="text-align: center; margin-top: 30px;">
            <p style="color: #666;">L'équipe BookFoot237<br>
            📧 contact@bookfoot237.cm | 📱 +237 6XX XXX XXX</p>
          </div>
        </div>
      </div>
      ''';

      final message = Message()
        ..from = Address(NotificationConfig.gmailUsername, 'BookFoot237')
        ..recipients.add(managerEmail)
        ..subject = subject
        ..html = htmlContent;

      final sendReport = await send(message, smtpServer);
      print('✅ Email d\'annulation gestionnaire envoyé avec succès: ${sendReport.toString()}');
      return true;

    } catch (e) {
      print('❌ Erreur envoi email annulation gestionnaire: $e');
      return false;
    }
  }
}