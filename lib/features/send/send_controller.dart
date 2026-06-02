import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../data/models/transfer_result.dart';
import '../../data/repositories/customer_repository.dart';
import '../customer/customer_providers.dart';

/// What the P2P flow needs the UI to do next.
enum SendPhase { idle, submitting, needsConfirmation, needsPin, executed, error }

class SendState {
  const SendState({
    this.phase = SendPhase.idle,
    this.result,
    this.errorMessage,
    this.matchedThreshold,
  });

  final SendPhase phase;
  final P2pTransferResult? result;
  final String? errorMessage;
  final int? matchedThreshold;

  SendState copyWith({
    SendPhase? phase,
    P2pTransferResult? result,
    String? errorMessage,
    int? matchedThreshold,
    bool clearError = false,
  }) =>
      SendState(
        phase: phase ?? this.phase,
        result: result ?? this.result,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        matchedThreshold: matchedThreshold ?? this.matchedThreshold,
      );
}

/// Drives the P2P control-gate loop (spec §10.3). A single intent reuses one
/// [idempotencyKey] across the confirmation/PIN resubmits; a brand-new amount
/// or recipient should construct a fresh controller (new key).
class SendController extends StateNotifier<SendState> {
  SendController(
    this._ref, {
    required this.recipientCountryCode,
    required this.recipientPhone,
    required this.amount,
    this.description,
  })  : _idempotencyKey = newIdempotencyKey(),
        super(const SendState());

  final Ref _ref;
  final String recipientCountryCode;
  final String recipientPhone;
  final int amount;
  final String? description;

  // Reused across all resubmits for this intent (critical for §2.4 semantics).
  final String _idempotencyKey;

  bool _confirmationAcknowledged = false;

  CustomerRepository get _repo => _ref.read(customerRepositoryProvider);

  /// First submit — probes for any control gate.
  Future<void> submit() => _send();

  /// Resubmit after the user acknowledges the confirmation prompt.
  Future<void> acknowledgeConfirmation() {
    _confirmationAcknowledged = true;
    return _send();
  }

  /// Resubmit with the entered PIN (also carries any earlier confirmation ack).
  Future<void> submitPin(String pin) => _send(pin: pin);

  Future<void> _send({String? pin}) async {
    state = state.copyWith(phase: SendPhase.submitting, clearError: true);
    try {
      final res = await _repo.sendP2p(
        idempotencyKey: _idempotencyKey,
        recipientCountryCode: recipientCountryCode,
        recipientPhone: recipientPhone,
        amount: amount,
        description: description,
        pin: pin,
        confirmationAcknowledged:
            _confirmationAcknowledged ? true : null,
      );
      if (res.isExecuted) {
        // Refresh balance/activity since the wallet moved, and beneficiaries
        // since this recipient is now a recent (a freshly typed number that
        // wasn't in the list should appear next time).
        _ref.invalidate(balanceProvider);
        _ref.invalidate(activityProvider);
        _ref.invalidate(beneficiariesProvider);
        _ref.invalidate(unreadCountProvider);
        state = state.copyWith(phase: SendPhase.executed, result: res);
      } else if (res.needsConfirmation) {
        state = state.copyWith(
          phase: SendPhase.needsConfirmation,
          result: res,
          matchedThreshold: res.matchedThresholdAmount,
        );
      } else if (res.needsPin) {
        state = state.copyWith(phase: SendPhase.needsPin, result: res);
      } else {
        state = state.copyWith(
            phase: SendPhase.error,
            errorMessage: 'Réponse inattendue du serveur.');
      }
    } on ApiError catch (e) {
      state = state.copyWith(
          phase: SendPhase.error, errorMessage: frenchMessageForError(e));
    } catch (_) {
      state = state.copyWith(
          phase: SendPhase.error, errorMessage: 'Une erreur est survenue.');
    }
  }
}

/// Parameters identifying a single send intent.
class SendArgs {
  const SendArgs({
    required this.recipientCountryCode,
    required this.recipientPhone,
    required this.amount,
    this.description,
  });
  final String recipientCountryCode;
  final String recipientPhone;
  final int amount;
  final String? description;
}

final sendControllerProvider = StateNotifierProvider.autoDispose
    .family<SendController, SendState, SendArgs>((ref, args) {
  return SendController(
    ref,
    recipientCountryCode: args.recipientCountryCode,
    recipientPhone: args.recipientPhone,
    amount: args.amount,
    description: args.description,
  );
});
