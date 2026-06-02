# Icône de l'application Lipa

Placez ici votre logo Lipa pour générer l'icône de l'application.

## Fichier attendu

- **Nom :** `lipa_icon.png`
- **Chemin :** `app/assets/icon/lipa_icon.png`
- **Format :** PNG carré **1024 × 1024 px**
- Idéalement avec une marge de sécurité (~10 %) autour du logo, car Android
  peut rogner les coins (icônes adaptatives).

## Génération des icônes

Une fois le fichier en place, exécutez depuis le dossier `app/` :

```
flutter pub get
flutter pub run flutter_launcher_icons
```

Cela régénère automatiquement toutes les tailles `mipmap-*` (Android) et les
jeux d'icônes iOS à partir du PNG source. La configuration se trouve dans
`pubspec.yaml` sous la clé `flutter_launcher_icons`.
