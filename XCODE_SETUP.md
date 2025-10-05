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

#### ⚠️ IMPORTANT : Utilisez AppKit, PAS SwiftUI

Ce projet utilise AppKit (NSApplication) avec un fichier `main.swift` personnalisé. **NE CRÉEZ PAS** un projet SwiftUI avec `@main struct App`.

1. **Créer un nouveau projet Xcode avec AppKit**
   - Ouvrez Xcode
   - File > New > Project
   - Choisissez "macOS" > "App"
   - Nom : ARDroneController
   - Organization Identifier : com.quadlife
   - **Interface : Storyboard** (PAS SwiftUI - très important!)
   - Language : Swift
   - Décochez "Use Core Data" et "Include Tests"

2. **Supprimer les fichiers générés par défaut**
   - Supprimez **tous** les fichiers Swift créés par Xcode :
     - `AppDelegate.swift` (sera remplacé par notre `main.swift`)
     - `ViewController.swift`
   - Supprimez également `Main.storyboard` (nous utilisons des fenêtres programmatiques)

3. **Copier les fichiers source**
   - Glissez-déposez **tous** les fichiers du dossier `Sources/` dans votre projet Xcode
   - **Cochez** "Copy items if needed"
   - **Cochez** "Create groups"
   - **Assurez-vous** que le target "ARDroneController" est sélectionné
   
   Fichiers à copier :
   - `main.swift` (⚠️ très important - c'est le point d'entrée)
   - `ARDroneController.swift`
   - `StatusWindowController.swift`
   - `GamepadManager.swift`
   - `VideoStreamHandler.swift`
   - `NavData.swift`
   - `ATCommands.swift`
   - `DroneConfig.swift`
   - `SplashWindowController.swift`
   - `GlobalHotkeyManager.swift`

4. **Configurer l'Info.plist**
   - Ouvrez l'Info.plist de votre projet
   - **Supprimez** la clé `NSMainStoryboardFile` (nous n'utilisons pas de storyboard)
   - **Ajoutez** toutes les permissions du fichier `Info.plist` existant :
     ```xml
     <key>NSBluetoothAlwaysUsageDescription</key>
     <string>This app needs Bluetooth access to connect to your DualShock 4 controller.</string>
     <key>NSLocalNetworkUsageDescription</key>
     <string>This app needs local network access to communicate with your AR.Drone 2.0.</string>
     <key>NSLocationWhenInUseUsageDescription</key>
     <string>ARDrone Controller nécessite la localisation pour détecter le réseau Wi-Fi du drone.</string>
     ```
   - Ou remplacez complètement l'Info.plist par le fichier existant

5. **Ajouter les ressources**
   - Glissez-déposez le dossier `Resources/` dans votre projet
   - Cochez "Create folder references" (pas "Create groups")
   - Assurez-vous que les ressources sont bien ajoutées au target
   - Vérifiez dans Build Phases > Copy Bundle Resources que `dualshock4.png` est présent

6. **Configurer les frameworks**
   - Allez dans Project Settings > General > Frameworks and Libraries
   - Ajoutez si nécessaire (normalement automatique) :
     - CoreWLAN.framework
   - Les autres frameworks sont automatiques :
     - Cocoa
     - AVFoundation
     - GameController
     - Network

7. **Vérifier la configuration du target**
   - Dans Build Settings, cherchez "Info.plist File"
   - Assurez-vous qu'il pointe vers votre Info.plist
   - Vérifiez que "Deployment Target" est macOS 13.0 minimum

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

### Problème : J'ai créé un projet SwiftUI par erreur avec `@main struct App`

**Symptôme** : Vous avez un fichier comme celui-ci :
```swift
import SwiftUI

@main
struct ARDrone_Parrot_2_0___DualShock_4___SwiftApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**Solution** : Ce projet n'utilise PAS SwiftUI, il utilise AppKit avec un fichier `main.swift` personnalisé.

**Options** :

**Option A - Recréer le projet correctement (recommandé)** :
1. Fermez Xcode
2. Supprimez le projet SwiftUI que vous avez créé
3. Suivez les instructions "Option 2" ci-dessus en choisissant **Storyboard** comme interface (pas SwiftUI)
4. Copiez les fichiers Sources/ dans le nouveau projet
5. N'oubliez pas d'inclure `main.swift` - c'est le point d'entrée de l'application

**Option B - Convertir le projet SwiftUI existant** :
1. **Supprimez** le fichier `@main struct App` que Xcode a créé
2. **Supprimez** `ContentView.swift`
3. **Copiez** tous les fichiers du dossier `Sources/` dans votre projet
4. **Assurez-vous** que `main.swift` est bien copié - il contient le point d'entrée de l'app
5. Dans Info.plist, **supprimez** toute référence à `NSMainStoryboardFile` ou SwiftUI
6. Compilez - Xcode devrait maintenant utiliser le `main.swift` comme point d'entrée

**Pourquoi ce projet utilise `main.swift` au lieu de `@main` ?**
- Ce projet crée une application AppKit traditionnelle avec NSApplication
- Il a besoin d'un contrôle total sur le cycle de vie de l'application
- Le fichier `main.swift` à la ligne 126-152 initialise manuellement l'application :
  ```swift
  let app = NSApplication.shared
  let delegate = AppDelegate()
  app.delegate = delegate
  app.run()
  ```

### Problème : "Cannot find 'main' in scope"
**Solution** : Vous essayez d'importer un module appelé `main`. Ce n'est pas un module, c'est le point d'entrée de l'application. Supprimez l'import `import main` et assurez-vous que le fichier `main.swift` est dans votre projet.

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
