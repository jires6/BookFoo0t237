# 📧📱 Configuration des Services d'Envoi Email et SMS

## 🎯 **Objectif**
Permettre l'envoi **réel** d'emails et de SMS vers les adresses et numéros des utilisateurs lors de la vérification OTP.

---

## 📧 **CONFIGURATION EMAIL**

### **Option 1: Gmail SMTP (Recommandé - Gratuit)**

#### **Étapes:**
1. **Créer/Utiliser un compte Gmail**
   - Si vous n'en avez pas, créez un compte Gmail sur https://gmail.com

2. **Activer l'authentification à 2 facteurs**
   - Allez sur https://myaccount.google.com/security
   - Activez l'authentification à 2 facteurs

3. **Générer un mot de passe d'application**
   - Toujours dans la sécurité Google
   - Cliquez sur "Mots de passe d'applications"
   - Sélectionnez "Autre (nom personnalisé)" → tapez "BookFoot237"
   - **Notez le mot de passe généré** (16 caractères)

4. **Configurer dans l'app**
   - Ouvrez `lib/config/notification_config.dart`
   - Remplacez:
   ```dart
   static const String gmailUsername = 'votre_email@gmail.com';
   static const String gmailAppPassword = 'votre_mot_de_passe_app_16_caracteres';
   ```
   - Par vos vraies valeurs:
   ```dart
   static const String gmailUsername = 'votrecompte@gmail.com';
   static const String gmailAppPassword = 'abcd efgh ijkl mnop'; // Mot de passe d'app
   ```

### **Option 2: EmailJS (Gratuit, plus simple)**

#### **Étapes:**
1. **Créer un compte EmailJS**
   - Allez sur https://emailjs.com
   - Créez un compte gratuit

2. **Configurer un service email**
   - Dans EmailJS, allez à "Email Services"
   - Cliquez "Add New Service" → Choisissez Gmail/Outlook/Yahoo
   - Connectez votre compte email

3. **Créer un template email**
   - Allez à "Email Templates" → "Create New Template"
   - Template de base:
   ```
   Sujet: Code BookFoot237 - {{otp_code}}
   
   Bonjour,
   Votre code de vérification BookFoot237: {{otp_code}}
   Valide 5 minutes.
   ```

4. **Récupérer vos IDs**
   - Service ID: dans "Email Services"
   - Template ID: dans "Email Templates"  
   - User ID: dans "Account" → "General"

5. **Configurer dans l'app**
   ```dart
   static const String emailJsServiceId = 'service_xxxxxxxxx';
   static const String emailJsTemplateId = 'template_xxxxxxxxx';  
   static const String emailJsUserId = 'xxxxxxxxx';
   ```

---

## 📱 **CONFIGURATION SMS**

### **Option 1: Firebase Phone Auth (Recommandé)**

#### **Étapes:**
1. **Console Firebase**
   - https://console.firebase.google.com
   - Projet: `bookfoot237-99459`

2. **Activer Phone Authentication**
   - Authentication → Sign-in method
   - Activer "Phone"

3. **Configurer pour le Cameroun**
   - Dans "Phone numbers for testing", ajoutez:
   - `+237612345678` avec code `123456` (pour tests)

4. **Production: Activer facturation**
   - Firebase nécessite facturation pour SMS en production
   - Dans Console → Billing → Upgrade to Blaze Plan

### **Option 2: Twilio SMS (Payant mais fiable)**

#### **Étapes:**
1. **Créer compte Twilio**
   - https://twilio.com → Sign up
   - Vous recevez 15$ de crédit gratuit

2. **Obtenir les identifiants**
   - Account SID: dans Dashboard
   - Auth Token: dans Dashboard  
   - Numéro Twilio: acheter un numéro (+1 ou +237)

3. **Configurer dans l'app**
   ```dart
   static const String twilioAccountSid = 'ACxxxxxxxxx';
   static const String twilioAuthToken = 'xxxxxxxxx';
   static const String twilioPhoneNumber = '+1234567890';
   ```

### **Option 3: Services locaux Cameroun**

#### **Orange Cameroun API SMS:**
- Contact: Orange Business pour API
- Documentation: https://developer.orange.com

#### **MTN Cameroun API SMS:**  
- Contact: MTN Business pour API
- Documentation: Demander à MTN

---

## ⚙️ **MISE EN PRODUCTION**

### **Variables d'environnement (Sécurisé)**

**Au lieu de hardcoder dans `notification_config.dart`, utilisez:**

1. **Flutter dotenv:**
   ```bash
   flutter pub add flutter_dotenv
   ```

2. **Créez `.env` (ne pas commiter!):**
   ```
   GMAIL_USERNAME=votrecompte@gmail.com
   GMAIL_APP_PASSWORD=abcd efgh ijkl mnop
   TWILIO_ACCOUNT_SID=ACxxxxxxxxx
   TWILIO_AUTH_TOKEN=xxxxxxxxx
   ```

3. **Chargez dans l'app:**
   ```dart
   await dotenv.load();
   final gmailUsername = dotenv.env['GMAIL_USERNAME']!;
   ```

---

## 🧪 **TEST DE FONCTIONNEMENT**

### **Email:**
1. Configurez au moins Gmail ou EmailJS
2. Dans l'app, choisissez "Par Email"
3. Entrez votre vraie adresse email
4. Cliquez "Envoyer code email"
5. **Vérifiez votre boîte email** (et spam!)

### **SMS:**
1. Configurez Firebase Phone Auth ou Twilio
2. Dans l'app, choisissez "Par SMS" 
3. Entrez votre vrai numéro (+237...)
4. Cliquez "Envoyer code SMS"
5. **Vérifiez vos SMS**

---

## 🔧 **DÉPANNAGE**

### **Email ne fonctionne pas:**
- Vérifiez le mot de passe d'application Gmail (pas le mot de passe normal)
- Vérifiez que l'authentification 2FA est activée
- Regardez les logs Flutter pour les erreurs détaillées

### **SMS ne fonctionne pas:**
- Firebase: vérifiez que Phone Auth est activé
- Twilio: vérifiez le crédit disponible
- Vérifiez le format du numéro (+237xxxxxxxxx)

### **Logs utiles:**
Regardez la console Flutter pour voir:
```
I/flutter: Email Gmail envoyé: Success
I/flutter: SMS envoyé avec succès à +237612345678
```

---

## 💰 **COÛTS**

### **Gratuit:**
- Gmail SMTP: Gratuit (limite Gmail normale)
- EmailJS: 200 emails/mois gratuits
- Firebase SMS: Gratuit pour tests, payant en production

### **Payant:**
- Twilio SMS: ~0.0075$/SMS
- SendGrid: Plans à partir de 15$/mois
- Firebase SMS: ~0.01$/SMS (après facturation activée)

---

## 🚀 **MISE À JOUR RAPIDE**

**Pour activer immédiatement Gmail:**

1. **Configurez Gmail** (étapes ci-dessus)
2. **Modifiez** `lib/config/notification_config.dart`:
   ```dart
   static const String gmailUsername = 'VOTRE_VRAI_EMAIL@gmail.com';
   static const String gmailAppPassword = 'VOTRE_MOT_DE_PASSE_16_CHAR';
   ```
3. **Relancez l'app**
4. **Testez** avec votre vraie adresse email!

Les emails seront maintenant **réellement envoyés** ! 📧✅