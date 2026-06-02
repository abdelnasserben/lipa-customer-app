/// Backend error code → typed handling. Mirrors the codes listed in the
/// Customer spec §11 (UI States & Business Errors).
///
/// We keep the raw `code` string so unknown/future codes never crash the app.
class ApiError implements Exception {
  const ApiError({
    required this.statusCode,
    required this.code,
    this.message,
    this.details = const [],
    this.correlationId,
  });

  final int statusCode;
  final String code;
  final String? message;
  final List<String> details;
  final String? correlationId;

  /// Parses both the wrapped `{ "error": {...} }` envelope (controller /
  /// validation / 429) and the raw `ApiError` body that Spring Security emits
  /// for 401/403. See spec §2.3.
  factory ApiError.fromResponse(int statusCode, Object? body) {
    Map<String, dynamic>? err;
    if (body is Map<String, dynamic>) {
      final wrapped = body['error'];
      if (wrapped is Map<String, dynamic>) {
        err = wrapped;
      } else if (body.containsKey('code')) {
        err = body; // raw ApiError (security filter)
      }
    }
    final details = <String>[];
    final rawDetails = err?['details'];
    if (rawDetails is List) {
      details.addAll(rawDetails.map((e) => e.toString()));
    }
    return ApiError(
      statusCode: statusCode,
      code: (err?['code'] as String?) ?? _fallbackCode(statusCode),
      message: err?['message'] as String?,
      details: details,
      correlationId: err?['correlationId'] as String?,
    );
  }

  static String _fallbackCode(int status) {
    switch (status) {
      case 401:
        return 'UNAUTHORIZED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 429:
        return 'TERMINAL_RATE_LIMIT';
      default:
        return 'UNKNOWN_ERROR';
    }
  }

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// True for the 422 codes that mean the actor's account/wallet is unusable
  /// and not self-recoverable (spec §11.1/§11.2).
  bool get isAccountBlocked => const {
        'ACTOR_PENDING_KYC',
        'ACTOR_SUSPENDED',
        'ACTOR_CLOSED',
        'ACTOR_FROZEN',
        'WALLET_FROZEN',
        'WALLET_SUSPENDED',
        'WALLET_CLOSED',
      }.contains(code);

  /// A network/transport failure with no HTTP response (timeout, no route).
  factory ApiError.network([String? message]) => ApiError(
        statusCode: 0,
        code: 'NETWORK_ERROR',
        message: message ?? 'Connexion impossible. Vérifiez votre réseau.',
      );

  @override
  String toString() => 'ApiError($statusCode $code: ${message ?? ''})';
}

/// Maps backend error codes to user-facing French copy, aligned with spec §11.
/// Falls back to a generic message for unknown codes — never leaks raw codes.
String frenchMessageForError(ApiError e) {
  switch (e.code) {
    // Session / auth
    case 'INVALID_CREDENTIALS':
      return 'Numéro ou PIN incorrect.';
    case 'AUTH_PIN_INVALID':
      return 'PIN incorrect. Réessayez.';
    case 'AUTH_PIN_LOCKED':
      return 'PIN bloqué. Réessayez dans 15 minutes.';
    case 'AUTH_PIN_FORMAT':
      return 'Le PIN doit comporter 4 à 8 chiffres.';
    case 'AUTH_PIN_ALREADY_SET':
      return 'Un PIN est déjà défini pour ce compte.';
    case 'AUTH_PIN_NOT_SET':
      return 'Aucun PIN n’est défini pour ce compte.';
    case 'AUTH_PIN_RESET_TOTP_REQUIRED':
      return 'Activez le TOTP ou contactez le support pour réinitialiser votre PIN.';
    case 'AUTH_MFA_INVALID':
    case 'MFA_INVALID':
      return 'Code de vérification invalide.';
    case 'REFRESH_TOKEN_INVALID':
      return 'Votre session a expiré. Reconnectez-vous.';
    case 'TERMINAL_RATE_LIMIT':
      return 'Trop de tentatives. Réessayez dans un instant.';
    case 'ACTOR_PENDING_KYC':
      return 'Votre compte est en cours de vérification.';
    case 'ACTOR_SUSPENDED':
    case 'ACTOR_CLOSED':
    case 'ACTOR_FROZEN':
      return 'Compte indisponible. Contactez le support Lipa.';

    // Financial / business
    case 'INSUFFICIENT_BALANCE':
      return 'Solde insuffisant.';
    case 'LIMIT_EXCEEDED':
      return 'Plafond dépassé. Consultez vos plafonds.';
    case 'WALLET_FROZEN':
    case 'WALLET_SUSPENDED':
    case 'WALLET_CLOSED':
      return 'Portefeuille indisponible. Contactez le support.';
    case 'CONFIG_LIMIT_PROFILE_NOT_FOUND':
    case 'CONFIG_RULE_INACTIVE':
      return 'Service temporairement indisponible. Réessayez plus tard.';
    case 'CUSTOMER_NOT_FOUND':
      return 'Ce numéro ne correspond à aucun client Lipa.';
    case 'TRANSACTION_NOT_FOUND':
    case 'CARD_NOT_FOUND':
      return 'Introuvable.';
    case 'SERVICE_PROVIDER_IN_MAINTENANCE':
      return 'Service temporairement indisponible.';
    case 'BILL_PAYMENT_INVALID_REFERENCE_FORMAT':
      return 'Référence invalide pour ce fournisseur.';
    case 'BILL_PAYMENT_INVALID_TRANSITION':
      return 'Cette facture ne peut plus être annulée.';
    case 'PAYMENT_REQUEST_NOT_FOUND':
      return 'Code introuvable.';
    case 'PAYMENT_REQUEST_ALREADY_SETTLED':
      return 'Cette demande a déjà été réglée.';
    case 'PAYMENT_REQUEST_EXPIRED':
      return 'Cette demande de paiement a expiré.';
    case 'DUPLICATE_IDEMPOTENCY_KEY':
      return 'Opération déjà en cours de traitement.';
    case 'NETWORK_ERROR':
      return e.message ?? 'Connexion impossible. Vérifiez votre réseau.';
    default:
      return e.message ?? 'Une erreur est survenue. Réessayez.';
  }
}
