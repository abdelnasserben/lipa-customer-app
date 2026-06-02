import '../../core/auth/token_store.dart';

/// LoginResponse (spec §7.1) — three mutually exclusive branches:
///  A. full session (tokens populated)
///  B. mfaRequired (challengeId + mfaFactor)
///  C. pinSetupRequired (pinSetupToken)
class LoginResponse {
  const LoginResponse({
    required this.mfaRequired,
    required this.pinSetupRequired,
    this.tokens,
    this.challengeId,
    this.mfaFactor,
    this.pinSetupToken,
    this.pinSetupTokenExpiresAt,
  });

  final bool mfaRequired;
  final bool pinSetupRequired;
  final AuthTokens? tokens;
  final String? challengeId;
  final String? mfaFactor;
  final String? pinSetupToken;
  final DateTime? pinSetupTokenExpiresAt;

  /// Which branch is active. Order matters per spec §10.1:
  /// pinSetupRequired → mfaRequired → tokens.
  LoginBranch get branch {
    if (pinSetupRequired) return LoginBranch.pinSetup;
    if (mfaRequired) return LoginBranch.mfa;
    if (tokens != null) return LoginBranch.session;
    return LoginBranch.unknown;
  }

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final t = json['tokens'];
    return LoginResponse(
      mfaRequired: (json['mfaRequired'] ?? false) as bool,
      pinSetupRequired: (json['pinSetupRequired'] ?? false) as bool,
      tokens: t is Map<String, dynamic> ? AuthTokens.fromJson(t) : null,
      challengeId: json['challengeId'] as String?,
      mfaFactor: json['mfaFactor'] as String?,
      pinSetupToken: json['pinSetupToken'] as String?,
      pinSetupTokenExpiresAt: json['pinSetupTokenExpiresAt'] is String
          ? DateTime.tryParse(json['pinSetupTokenExpiresAt'] as String)
          : null,
    );
  }
}

enum LoginBranch { session, mfa, pinSetup, unknown }
