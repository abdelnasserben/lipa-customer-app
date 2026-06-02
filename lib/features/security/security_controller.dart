import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/repositories/auth_repository.dart';

/// Local TOTP-enrolled flag. The customer profile carries no TOTP field
/// (spec §7.2), so the app tracks enrollment state for this session. Login's
/// `mfaRequired` branch is the authoritative cross-device signal; this keeps
/// the Security screen in sync after enroll/revoke within a session.
final totpEnrolledProvider = StateProvider<bool>((ref) => false);

/// Thin facade over the auth repo for PIN/TOTP management used by the Security
/// screens. Keeps the screens free of repository wiring.
class SecurityActions {
  SecurityActions(this._ref);
  final Ref _ref;

  AuthRepository get _auth => _ref.read(authRepositoryProvider);

  Future<void> changePin({required String currentPin, required String newPin}) =>
      _auth.changePin(currentPin: currentPin, newPin: newPin);

  Future<TotpSetup> startTotpSetup() => _auth.startTotpSetup();

  Future<void> confirmTotp(String code) async {
    await _auth.confirmTotp(code);
    _ref.read(totpEnrolledProvider.notifier).state = true;
  }

  Future<void> revokeTotp(String code) async {
    await _auth.revokeTotp(code);
    _ref.read(totpEnrolledProvider.notifier).state = false;
  }
}

final securityActionsProvider = Provider<SecurityActions>((ref) {
  return SecurityActions(ref);
});
