# Configuration Firebase pour BookFoot237 Android

## Vue d'ensemble
Ce guide détaille la procédure complète pour configurer Firebase Authentication dans l'application BookFoot237 Android.

## Étape 1: Création du projet Firebase

### 1.1 Accéder à la console Firebase
1. Aller sur [https://console.firebase.google.com/](https://console.firebase.google.com/)
2. Se connecter avec votre compte Google
3. Cliquer sur **"Créer un projet"**

### 1.2 Configuration du projet
1. **Nom du projet** : `BookFoot237`
2. **Identifier du projet** : `bookfoot237-[id-unique]` (généré automatiquement)
3. **Région** : Europe (europe-west1) ou US-Central1
4. **Analytics** : Activer Google Analytics (recommandé)
5. Cliquer sur **"Créer le projet"**

## Étape 2: Ajout de l'application Android

### 2.1 Enregistrer l'application Android
1. Dans la console Firebase, cliquer sur l'icône Android
2. **Nom du package Android** : `com.bookfoot237.app.bookfoot237`
3. **Nom de l'application** : `BookFoot237`
4. **Certificat de signature** : Laisser vide pour le debug
5. Cliquer sur **"Enregistrer l'application"**

### 2.2 Informations de configuration actuelles
D'après la structure du projet Flutter (utilise Kotlin DSL) :
```
C:\Users\cabrelle\Desktop\Box\bookfoot237\
├── android/
│   ├── app/
│   │   ├── build.gradle.kts (app-level) ← Kotlin DSL
│   │   └── src/main/
│   │       └── AndroidManifest.xml
│   ├── build.gradle.kts (project-level) ← Kotlin DSL
│   ├── settings.gradle.kts ← Kotlin DSL
│   └── gradle.properties
├── lib/
│   └── main.dart
└── pubspec.yaml
```

**Informations extraites du build.gradle.kts :**
- **Application ID** : `com.bookfoot237.app.bookfoot237`
- **Namespace** : `com.bookfoot237.app.bookfoot237`
- **Compile SDK** : Défini par Flutter
- **Min SDK** : Défini par Flutter
- **Target SDK** : Défini par Flutter

## Étape 3: Téléchargement du fichier de configuration

### 3.1 Télécharger google-services.json
1. Dans la console Firebase, cliquer sur **"Télécharger google-services.json"**
2. Enregistrer le fichier téléchargé

### 3.2 Placement du fichier
**IMPORTANT** : Placer le fichier `google-services.json` dans le répertoire :
```
C:\Users\cabrelle\Desktop\Box\bookfoot237\android\app\google-services.json
```

**Structure finale** :
```
android/
├── app/
│   ├── google-services.json  ← PLACER ICI
│   ├── build.gradle
│   └── src/main/AndroidManifest.xml
└── build.gradle
```

## Étape 4: Configuration Gradle

### 4.1 Modifier android/settings.gradle.kts (niveau projet)
Fichier : `C:\Users\cabrelle\Desktop\Box\bookfoot237\android\settings.gradle.kts`

**Modifier la section plugins** :
```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // AJOUTER CETTE LIGNE
    id("com.google.gms.google-services") version "4.4.0" apply false
}
```

### 4.2 Modifier android/app/build.gradle.kts (niveau app)
Fichier : `C:\Users\cabrelle\Desktop\Box\bookfoot237\android\app\build.gradle.kts`

**Modifier la section plugins** :
```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // AJOUTER CETTE LIGNE
    id("com.google.gms.google-services")
}
```

**Ajouter la section dependencies à la fin du fichier** :
```kotlin
dependencies {
    // AJOUTER CES LIGNES
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}
```

## Étape 5: Configuration pubspec.yaml

### 5.1 Modifier pubspec.yaml
Fichier : `C:\Users\cabrelle\Desktop\Box\bookfoot237\pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^12.1.3
  shared_preferences: ^2.2.2
  intl: ^0.19.0
  # AJOUTER CES LIGNES
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## Étape 6: Activation de Firebase Authentication

### 6.1 Activer l'authentification
1. Dans la console Firebase, aller dans **"Authentication"**
2. Cliquer sur **"Commencer"**
3. Aller dans l'onglet **"Sign-in method"**

### 6.2 Configurer les méthodes de connexion
**Activer Email/Password** :
1. Cliquer sur **"Email/Password"**
2. Activer **"Activer"**
3. Laisser **"Email link (passwordless sign-in)"** désactivé
4. Cliquer sur **"Enregistrer"**

**Autres méthodes recommandées** :
- Google Sign-In (optionnel)
- Téléphone (optionnel)

## Étape 7: Configuration Android Manifest

### 7.1 Modifier AndroidManifest.xml
Fichier : `C:\Users\cabrelle\Desktop\Box\bookfoot237\android\app\src\main\AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- AJOUTER CES PERMISSIONS -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:label="BookFoot237"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
              
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

## Étape 8: Configuration de l'application Flutter

### 8.1 Initialiser Firebase dans main.dart
Modifier `C:\Users\cabrelle\Desktop\Box\bookfoot237\lib\main.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ... autres imports

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // AJOUTER CES LIGNES
  await Firebase.initializeApp();
  
  runApp(const BookFootApp());
}

// Classe pour gérer l'authentification Firebase
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Inscription avec email/password
  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print('Erreur inscription: $e');
      return null;
    }
  }
  
  // Connexion avec email/password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print('Erreur connexion: $e');
      return null;
    }
  }
  
  // Déconnexion
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print('Erreur déconnexion: $e');
    }
  }
  
  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;
  
  // Stream des changements d'état
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
```

## Étape 9: Commandes à exécuter

### 9.1 Installation des dépendances
```bash
cd "C:\Users\cabrelle\Desktop\Box\bookfoot237"
flutter pub get
```

### 9.2 Nettoyage et reconstruction
```bash
flutter clean
flutter pub get
```

### 9.3 Test de la configuration
```bash
# Vérifier que Firebase est correctement configuré
flutter run --debug
```

## Étape 10: Vérification de la configuration

### 10.1 Checklist finale (adaptée pour Kotlin DSL)
- [ ] `google-services.json` dans `android/app/`
- [ ] `android/settings.gradle.kts` modifié (google-services plugin)
- [ ] `android/app/build.gradle.kts` modifié (firebase dependencies)
- [ ] `pubspec.yaml` avec firebase packages
- [ ] `AndroidManifest.xml` avec permissions
- [ ] Firebase Authentication activé dans la console
- [ ] Email/Password method activé
- [ ] Application ID correcte : `com.bookfoot237.app.bookfoot237`

### 10.2 Test de connexion
1. Lancer l'app : `flutter run -d "R58XB0G405M"`
2. Vérifier que Firebase se connecte dans les logs
3. Tester l'inscription/connexion

## Configuration spécifique au projet

### Informations du projet actuel (extraites des fichiers de configuration)
- **Répertoire** : `C:\Users\cabrelle\Desktop\Box\bookfoot237`
- **Application ID** : `com.bookfoot237.app.bookfoot237`
- **Namespace** : `com.bookfoot237.app.bookfoot237`
- **Device ID** : `R58XB0G405M` (SM A165F)
- **Version Flutter** : Dernière stable
- **Plateforme** : Windows
- **Gradle** : Kotlin DSL (.gradle.kts)
- **Android Gradle Plugin** : 8.9.1
- **Kotlin** : 2.1.0

### Firebase Project Settings recommandés
- **Nom** : BookFoot237
- **Plan** : Spark (gratuit)
- **Région** : europe-west1
- **Authentication** : Email/Password activé
- **Firestore** : Mode test (pour commencer)

## Dépannage courant

### Erreurs fréquentes
1. **google-services.json manquant** : Vérifier l'emplacement exact
2. **Plugin non appliqué** : Vérifier les modifications gradle
3. **Dependencies manquantes** : Exécuter `flutter pub get`
4. **Permissions manquantes** : Vérifier AndroidManifest.xml

### Logs à surveiller
```bash
flutter run --verbose
# Rechercher: "Firebase initialized successfully"
```

---

**Note** : Cette configuration permettra de remplacer progressivement SharedPreferences par Firebase Authentication pour une authentification cloud sécurisée.