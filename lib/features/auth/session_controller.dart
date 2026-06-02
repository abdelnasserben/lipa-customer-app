import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// High-level session state that drives the root router (logged in vs auth).
enum SessionStatus { unknown, unauthenticated, authenticated }

class SessionState {
  const SessionState({required this.status, this.expiredNotice = false});

  final SessionStatus status;

  /// True right after an involuntary logout (token expiry) so the auth screen
  /// can show the "session expired" variant.
  final bool expiredNotice;

  SessionState copyWith({SessionStatus? status, bool? expiredNotice}) =>
      SessionState(
        status: status ?? this.status,
        expiredNotice: expiredNotice ?? this.expiredNotice,
      );
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref)
      : super(const SessionState(status: SessionStatus.unknown)) {
    _bootstrap();
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    // Wire the API client's involuntary-logout signal back to us.
    _ref.read(apiClientProvider).onSessionExpired = _onSessionExpired;
    final tokenStore = _ref.read(tokenStoreProvider);
    final tokens = await tokenStore.load();
    final hasValidRefresh =
        tokens != null && DateTime.now().isBefore(tokens.refreshTokenExpiresAt);
    state = SessionState(
      status: hasValidRefresh
          ? SessionStatus.authenticated
          : SessionStatus.unauthenticated,
    );
  }

  /// Called by the auth flow after a successful login / MFA / token issue.
  void markAuthenticated() {
    state = const SessionState(status: SessionStatus.authenticated);
  }

  void _onSessionExpired() {
    if (state.status == SessionStatus.authenticated) {
      state = const SessionState(
          status: SessionStatus.unauthenticated, expiredNotice: true);
      _resetUserScopedState();
    }
  }

  Future<void> logout() async {
    try {
      await _ref.read(authRepositoryProvider).logout();
    } finally {
      state = const SessionState(status: SessionStatus.unauthenticated);
      _resetUserScopedState();
    }
  }

  /// Tears down per-user state that would otherwise leak across accounts.
  ///
  /// [customerRepositoryProvider] is a long-lived singleton that caches the
  /// signed-in user's `walletId` (used to derive transaction direction); we
  /// rebuild it so the next user starts clean.
  ///
  /// The user data providers (profile, balance, limits, activity, …) are all
  /// `autoDispose`: flipping `state` to `unauthenticated` first unmounts
  /// CustomerShell, which disposes them — so they neither serve the previous
  /// user's data nor refetch under the just-cleared token (which 401'd and left
  /// a stuck error). They start fresh on the next login. So we only need to
  /// reset the repository singleton here.
  void _resetUserScopedState() {
    _ref.invalidate(customerRepositoryProvider);
  }

  void clearExpiredNotice() {
    if (state.expiredNotice) {
      state = state.copyWith(expiredNotice: false);
    }
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref);
});
