# Lipa — Application mobile client

Application Flutter du portail **client Lipa** (portefeuille, transferts P2P, demandes
de paiement, factures, cartes). L'UI implémente le design `Lipa Customer.html` et
consomme l'API décrite dans `Customer_Frontend_Specification.md` (v2.0), qui fait
**foi** : on n'appelle et n'affiche rien qui n'y figure pas.

> « KomoPay » est le nom interne du backend — jamais montré à l'utilisateur. Toute la
> copie visible est en français, sous la marque **Lipa**. La devise est le **KMF**
> (entier, unité mineure).

## Stack

- **Flutter 3.44 / Dart 3.12**
- **Riverpod** — état + injection de dépendances
- **Dio** — client HTTP (intercepteurs : Bearer, refresh proactif + sur-401,
  `Idempotency-Key`, `X-Correlation-Id`, mapping d'erreurs)
- **flutter_secure_storage** — tokens dans le Keystore/Keychain
- **google_fonts** — Bricolage Grotesque (UI) + DM Mono (chiffres/codes)
- **go_router**, **intl**, **uuid**

## Architecture en couches

```
lib/
  core/            socle transverse
    config/        AppEnvironment / AppConfig (local|prod)
    theme/         tokens (couleurs, radius, ombres) + typographie
    network/       ApiClient (Dio), enveloppes ApiResponse/PagedResponse
    error/         ApiError typée + mapping code → message FR
    auth/          TokenStore (stockage sécurisé)
    utils/         formatters (KMF, téléphone, dates FR)
    widgets/       widgets partagés (LipaMark, boutons, pills, PinSheet…)
    providers.dart DI : câble les repositories API
  data/
    models/        DTOs alignés sur la spec §7 + enums §8
    repositories/  interfaces + implémentations API (Dio)
  features/        présentation, par domaine
    auth/ home/ activity/ notifications/ send/ pay/ cards/ profile/
  app.dart         racine : bascule auth ↔ shell selon la session
  main.dart        point d'entrée
```

Les écrans ne contiennent **aucune donnée brute** : ils lisent des providers Riverpod
qui appellent des *repositories* (implémentations API sur Dio, dans `data/repositories/`).

## Environnements (local / prod)

L'environnement est choisi au build via `--dart-define=ENV=...` (défaut : `local`) :

| ENV     | baseUrl par défaut                | Réseau ? |
|---------|-----------------------------------|----------|
| `local` | `http://localhost:8080`           | Oui — backend sur la machine de dev |
| `prod`  | `https://api.lipa.km`             | Oui — API de production |

On peut surcharger l'URL : `--dart-define=API_BASE_URL=https://...`.

**Vrai device (USB)** : ouvre le tunnel avant de lancer, puis `localhost` marche :

```bash
adb reverse tcp:8080 tcp:8080
flutter run --dart-define=ENV=local

# Build de production
flutter build apk --release --dart-define=ENV=prod
```

**Émulateur sans `adb reverse`** : utilise l'alias loopback de l'émulateur :

```bash
flutter run --dart-define=ENV=local --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## Points de conformité à la spec

- **Auth client** : login phone+PIN à trois branches (`pinSetupRequired` → `mfaRequired`
  → `tokens`), MFA TOTP, configuration de PIN. TTL access **15 min** → refresh proactif
  (~3 min avant expiration) + refresh sur 401, refresh rotatif.
- **Contrôle 202** (P2P / payment-request) : `EXECUTED` / `PENDING_PIN` /
  `PENDING_CONFIRMATION`, resoumission avec **le même `Idempotency-Key`** + `pin` /
  `confirmationAcknowledged`. Priorité confirmation puis PIN.
- **Idempotency-Key** généré (UUID) par intention financière, conservé pendant la boucle.
- **Enveloppes** `ApiResponse` / `PagedResponse` et **erreurs** (`{error:{…}}` ou
  `ApiError` brut sur 401/403) parsées de façon défensive ; enums tolérants (`unknown`).
- **Notifications** : inbox *pull-only*, badge via `/unread`, marquage lu optimiste,
  deep-link transaction (catégorie `BILL_PAYMENT` incluse).
- **Cartes** : liste/détail, signaler perdue/volée (idempotent). Pas d'émission côté
  client (renvoi vers un agent).
- **Plafonds** : `/me/limits` → `404` traité comme « non configurés » (pas une erreur).

## Périmètre

L'ensemble des flux de la spec est implémenté :

- **Auth** : login phone+PIN (3 branches), MFA TOTP, configuration de PIN.
- **Accueil**, **Activité + détail**, **Relevé**, **Notifications** (inbox pull-only).
- **Envoyer** (P2P avec contrôle 202), **Hub Payer** : paiement par code marchand
  (lookup + pay) et demandes de paiement.
- **Factures** : catalogue / initiation / suivi / reçu, derrière la sonde `404` du
  feature flag `billpay.enabled`.
- **Cartes** : liste / détail, signalement perdue/volée.
- **Profil** + **Plafonds** (`/me/limits`).
- **Sécurité** : enrôlement TOTP, changement de PIN, révocation TOTP.

## Plateformes

Android + iOS sont scaffoldés. Android est la cible de dev/test ; aucun choix technique
ne bloque iOS. Objectif final : Play Store + App Store.

## Tests rapides

```bash
flutter analyze         # 0 issue
flutter build apk --debug --dart-define=ENV=local
```
