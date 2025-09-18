# 🔥 Configuration Firebase Storage - BookFoot237

Guide complet pour configurer Firebase Storage et permettre l'affichage des images des stades dans l'application BookFoot237.

## 📋 Table des matières

- [Prérequis](#prérequis)
- [Configuration des règles de sécurité](#configuration-des-règles-de-sécurité)
- [Vérification de la configuration](#vérification-de-la-configuration)
- [Configuration CORS (optionnel)](#configuration-cors-optionnel)
- [Structure des fichiers](#structure-des-fichiers)
- [Dépannage](#dépannage)

## 🎯 Prérequis

- Projet Firebase configuré avec BookFoot237
- Firebase Storage activé
- Accès administrateur au projet Firebase

## ⚙️ Configuration des règles de sécurité

### Étape 1: Accéder aux règles Firebase Storage

1. Ouvrir la [Console Firebase](https://console.firebase.google.com)
2. Sélectionner le projet **bookfoot237**
3. Naviguer vers **Storage** dans le menu de gauche
4. Cliquer sur l'onglet **Rules** (Règles)

### Étape 2: Appliquer les nouvelles règles

Remplacer **tout le contenu** des règles existantes par le code suivant :

```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // 🖼️ IMAGES DES STADES
    // Permet l'affichage public des images des stades
    match /stadiums/{stadiumId}/{imageId} {
      // Lecture publique pour tous (affichage des images)
      allow read: if true;

      // Écriture uniquement pour les utilisateurs authentifiés
      allow write: if request.auth != null
                   && request.auth.token.email_verified == true;
    }

    // 📁 AUTRES FICHIERS
    // Accès restreint aux utilisateurs connectés
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### Étape 3: Publier les règles

1. Cliquer sur le bouton **"Publish"** (Publier)
2. Confirmer la publication dans la boîte de dialogue

## ✅ Vérification de la configuration

### Test des règles

1. Aller dans l'onglet **Files** (Fichiers)
2. Vérifier la présence du dossier `stadiums/`
3. Tester l'upload d'images depuis l'application
4. Vérifier l'affichage des images dans l'app

### URLs d'accès

Les images doivent être accessibles via des URLs au format :
```
https://firebasestorage.googleapis.com/v0/b/VOTRE-PROJECT-ID.appspot.com/o/stadiums%2Ftemp_1234567890%2Fimage.jpg?alt=media&token=...
```

## 🌐 Configuration CORS (optionnel)

Si les images ne se chargent pas malgré les règles correctes, configurer CORS :

### Prérequis CORS
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installé
- Accès en ligne de commande

### Étapes CORS

1. **Créer le fichier `cors.json`** :
```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600,
    "responseHeader": [
      "Content-Type",
      "Access-Control-Allow-Origin",
      "Access-Control-Allow-Methods"
    ]
  }
]
```

2. **Appliquer la configuration CORS** :
```bash
gsutil cors set cors.json gs://VOTRE-PROJECT-ID.appspot.com
```

3. **Vérifier la configuration** :
```bash
gsutil cors get gs://VOTRE-PROJECT-ID.appspot.com
```

## 📁 Structure des fichiers

L'application organise les images selon cette hiérarchie :

```
Firebase Storage
└── stadiums/
    ├── temp_1726672345678/           # ID temporaire du stade
    │   ├── 1726672345678_image1.jpg  # Image 1
    │   ├── 1726672345678_image2.jpg  # Image 2
    │   └── 1726672345678_image3.jpg  # Image 3
    ├── temp_1726672456789/           # Autre stade
    │   └── 1726672456789_image1.jpg  # Image du stade
    └── ...
```

### Conventions de nommage

- **Dossier** : `temp_{timestamp}`
- **Fichier** : `{timestamp}_{nom_original}`
- **Format** : JPG, PNG (optimisé à 80% de qualité)
- **Taille max** : 1920x1080 pixels

## 🐛 Dépannage

### ❌ Problème : Images ne s'affichent pas

**Causes possibles :**
- Règles Storage incorrectes
- URLs malformées
- Problèmes CORS

**Solutions :**
1. ✅ Vérifier les règles de sécurité
2. ✅ Tester une URL d'image directement dans le navigateur
3. ✅ Vérifier les logs Firebase Storage
4. ✅ Appliquer la configuration CORS

### ❌ Problème : Upload d'images échoue

**Causes possibles :**
- Utilisateur non authentifié
- Permissions insuffisantes
- Taille de fichier trop importante

**Solutions :**
1. ✅ Vérifier l'authentification utilisateur
2. ✅ Contrôler les permissions d'écriture
3. ✅ Vérifier la taille des images (< 10MB)
4. ✅ Consulter les logs d'erreur

### ❌ Problème : Erreur CORS

**Message d'erreur typique :**
```
Access to fetch at 'https://firebasestorage.googleapis.com/...'
has been blocked by CORS policy
```

**Solution :**
1. ✅ Appliquer la configuration CORS (voir section ci-dessus)
2. ✅ Attendre 5-10 minutes pour la propagation
3. ✅ Vider le cache du navigateur

## 📊 Monitoring et logs

### Consulter les métriques

1. **Console Firebase** → **Storage** → **Usage**
2. Surveiller :
   - Nombre de requêtes
   - Bande passante utilisée
   - Erreurs d'accès

### Logs d'erreur

Les erreurs sont visibles dans :
- **Console Firebase** → **Storage** → **Files** (onglet Errors)
- **Logs Flutter** de l'application
- **Console développeur** du navigateur

## 🔒 Sécurité

### Bonnes pratiques

✅ **Recommandé :**
- Lecture publique uniquement pour les images des stades
- Écriture restreinte aux utilisateurs authentifiés
- Validation des types de fichiers
- Limitation de la taille des uploads

❌ **À éviter :**
- Accès en écriture public
- Stockage d'informations sensibles
- URLs sans authentification pour les données privées

## ✅ Checklist finale

Avant de considérer la configuration comme terminée :

- [ ] Règles Firebase Storage appliquées et publiées
- [ ] Structure `stadiums/` visible dans Storage
- [ ] Test d'upload d'image depuis l'application réussi
- [ ] Test d'affichage des images dans l'app réussi
- [ ] URLs des images accessibles publiquement
- [ ] Configuration CORS appliquée (si nécessaire)
- [ ] Monitoring activé

## 📞 Support

En cas de problème persistant :

1. 📋 Vérifier chaque étape de ce guide
2. 🔍 Consulter les logs Firebase et Flutter
3. 🌐 Tester les URLs directement dans un navigateur
4. 📧 Contacter le support technique si nécessaire

---

**📱 Application :** BookFoot237 - Réservation de terrains de football à Yaoundé
**🔥 Version Firebase :** Storage Rules v2
**📅 Dernière mise à jour :** Septembre 2024

---

> ⚽ Une fois cette configuration terminée, les gestionnaires pourront uploader des images de leurs stades et tous les utilisateurs pourront les voir dans l'application !