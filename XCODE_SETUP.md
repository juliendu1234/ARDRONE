# Guide de Configuration Xcode pour ARDrone Controller

## Méthode Moderne (Recommandée) - Xcode 11+

Depuis Xcode 11, vous n'avez plus besoin de générer un fichier `.xcodeproj`. Xcode peut ouvrir directement les packages Swift.

### Étapes :

1. **Ouvrir le projet dans Xcode**
   ```bash
   cd /chemin/vers/ARDRONE
   open Package.swift
   ```
   
   Ou simplement glissez-déposez le fichier `Package.swift` sur l'icône Xcode.

2. **Xcode va automatiquement :**
   - Charger le projet
   - Résoudre les dépendances
   - Créer la structure de compilation nécessaire
   - Vous permettre de build et run directement

3. **Configuration du Scheme :**
   - Sélectionnez "ARDroneController" dans le sélecteur de scheme (en haut à gauche)
   - Sélectionnez "My Mac" comme destination
   - Appuyez sur ⌘R pour compiler et exécuter

### Avantages de cette méthode :
- ✅ Pas de fichiers générés à versionner
- ✅ Configuration toujours à jour avec Package.swift
- ✅ Compatible avec les dernières versions de Xcode
- ✅ Intégration native avec Swift Package Manager

## Méthode Alternative - Générer .xcodeproj (Ancienne méthode)

Si vous avez vraiment besoin d'un fichier `.xcodeproj` (pour des raisons de compatibilité ou de préférence personnelle), vous pouvez utiliser un outil tiers.

### Option 1 : Utiliser swift-package-generate-xcodeproj (Xcode 10 et antérieur)

```bash
# Installer l'outil (si nécessaire)
brew install swift-package-generate-xcodeproj

# Générer le projet
cd /chemin/vers/ARDRONE
swift package generate-xcodeproj
```

⚠️ **Note** : Cette commande est dépréciée dans Swift 5.9+ et ne fonctionne plus.

### Option 2 : Créer un projet Xcode manuellement

Si vous préférez vraiment avoir un `.xcodeproj` traditionnel :

1. **Créer un nouveau projet Xcode**
   - Ouvrez Xcode
   - File > New > Project
   - Choisissez "macOS" > "App"
   - Nom : ARDroneController
   - Organization Identifier : com.quadlife
   - Interface : AppKit (pas SwiftUI)
   - Language : Swift
   - Décochez "Use Core Data" et "Include Tests"

2. **Copier les fichiers source**
   - Supprimez les fichiers Swift de base créés par Xcode (AppDelegate.swift, etc.)
   - Glissez-déposez tous les fichiers du dossier `Sources/` dans votre projet
   - Cochez "Copy items if needed"

3. **Configurer l'Info.plist**
   - Remplacez le contenu de l'Info.plist du projet par celui du fichier `Info.plist` existant
   - Ou copiez les clés importantes (permissions Bluetooth, réseau, etc.)

4. **Ajouter les ressources**
   - Glissez-déposez le dossier `Resources/` dans votre projet
   - Assurez-vous que les ressources sont bien ajoutées au target

5. **Configurer les frameworks**
   - Dans Project Settings > General > Frameworks and Libraries
   - Les frameworks nécessaires sont déjà importés dans le code :
     - Cocoa (automatique pour macOS)
     - AVFoundation
     - GameController
     - CoreWLAN
     - Network

## Structure du Projet

```
ARDRONE/
├── Package.swift              # Configuration Swift Package Manager
├── Info.plist                # Configuration de l'application
├── Sources/                  # Code source
│   ├── main.swift           # Point d'entrée
│   ├── ARDroneController.swift
│   ├── StatusWindowController.swift
│   ├── GamepadManager.swift
│   ├── VideoStreamHandler.swift
│   ├── NavData.swift
│   ├── ATCommands.swift
│   ├── DroneConfig.swift
│   ├── SplashWindowController.swift
│   └── GlobalHotkeyManager.swift
└── Resources/               # Ressources (images, etc.)
    └── dualshock4.png
```

## Frameworks Requis

Tous ces frameworks font partie du SDK macOS standard :

- **Cocoa** : Interface utilisateur macOS
- **AVFoundation** : Traitement vidéo
- **GameController** : Support manette DualShock 4
- **CoreWLAN** : Détection réseau Wi-Fi
- **Network** : Connexion réseau avec le drone

## Configuration de Build

### Minimum Deployment Target
- macOS 13.0 (Ventura)

### Swift Version
- Swift 5.9+

### Architecture
- x86_64 (Intel)
- arm64 (Apple Silicon)

## Résolution de Problèmes

### Problème : "No such module 'Cocoa'"
**Solution** : Assurez-vous que votre destination de build est "My Mac" et non iOS Simulator.

### Problème : Erreurs de permissions
**Solution** : Vérifiez que toutes les clés de permissions sont présentes dans Info.plist :
- NSBluetoothAlwaysUsageDescription
- NSLocalNetworkUsageDescription
- NSLocationWhenInUseUsageDescription

### Problème : Les ressources ne sont pas trouvées
**Solution** : Vérifiez que le dossier Resources est bien ajouté au target dans Build Phases > Copy Bundle Resources.

## Commandes Utiles

```bash
# Compiler le projet (ligne de commande)
swift build

# Exécuter le projet
swift run

# Nettoyer le build
swift package clean

# Mettre à jour les dépendances
swift package update

# Résoudre les dépendances
swift package resolve
```

## Recommandation Finale

**Je vous recommande fortement d'utiliser la méthode moderne** (ouvrir Package.swift directement dans Xcode). C'est la méthode standard supportée par Apple depuis Xcode 11, et elle évite de nombreux problèmes de synchronisation entre le fichier de projet et le Package.swift.

Si vous rencontrez des difficultés spécifiques avec cette approche, n'hésitez pas à me décrire le problème exact que vous rencontrez.
