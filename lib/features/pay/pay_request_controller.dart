import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../data/models/transfer_result.dart';
import '../../data/repositories/customer_repository.dart';
import '../customer/customer_providers.dart';

/// Phase of the payment-request pay control-gate loop (spec §10 / §7.5).
enum PayReqPhase { idle, submitting, needsConfirmation, needsPin, executed, error }

class PayReqState {
  const PayReqState({
    this.phase = PayReqPhase.idle,
    this.result,
    this.errorMessage,
    this.matchedThreshold,
  });

  final PayReqPhase phase;
  final PayPaymentRequestResult? result;
  final String? errorMessage;
  final int? matchedThreshold;

  PayReqState copyWith({
    PayReqPhase? phase,
    PayPaymentRequestResult? result,
    String? errorMessage,
    int? matchedThreshold,
    bool clearError = false,
  }) =>
      PayReqState(
        phase: phase ?? this.phase,
        result: result ?? this.result,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        matchedThreshold: matchedThreshold ?? this.matchedThreshold,
      );
}

/// Drives the payment-request settlement 202 loop. One intent reuses a single
/// [idempotencyKey] across resubmits (spec §2.4 / §7.5).
class PayReqController extends StateNotifier<PayReqState> {
  PayReqController(this._ref, {required this.shortCode})
      : _idempotencyKey = newIdempotencyKey(),
        super(const PayReqState());

  final Ref _ref;
  final String shortCode;
  final String _idempotencyKey;
  bool _confirmationAcknowledged = false;

  CustomerRepository get _repo => _ref.read(customerRepositoryProvider);

  Future<void> submit() => _send();

  Future<void> acknowledgeConfirmation() {
    _confirmationAcknowledged = true;
    return _send();
  }

  Future<void> submitPin(String pin) => _send(pin: pin);

  Future<void> _send({String? pin}) async {
    state = state.copyWith(phase: PayReqPhase.submitting, clearError: true);
    try {
      final res = await _repo.payPaymentRequest(
        shortCode: shortCode,
        idempotencyKey: _idempotencyKey,
        pin: pin,
        confirmationAcknowledged: _confirmationAcknowledged ? true : null,
      );
      if (res.isExecuted) {
        _ref.invalidate(balanceProvider);
        _ref.invalidate(activityProvider);
        _ref.invalidate(unreadCountProvider);
        state = state.copyWith(phase: PayReqPhase.executed, result: res);
      } else if (res.needsConfirmation) {
        state = state.copyWith(
          phase: PayReqPhase.needsConfirmation,
          result: res,
          matchedThreshold: res.matchedThresholdAmount,
        );
      } else if (res.needsPin) {
        state = state.copyWith(phase: PayReqPhase.needsPin, result: res);
      } else {
        state = state.copyWith(
            phase: PayReqPhase.error,
            errorMessage: 'Réponse inattendue du serveur.');
      }
    } on ApiError catch (e) {
      state = state.copyWith(
          phase: PayReqPhase.error, errorMessage: frenchMessageForError(e));
    } catch (_) {
      state = state.copyWith(
          phase: PayReqPhase.error, errorMessage: 'Une erreur est survenue.');
    }
  }
}

final payReqControllerProvider = StateNotifierProvider.autoDispose
    .family<PayReqController, PayReqState, String>((ref, shortCode) {
  return PayReqController(ref, shortCode: shortCode);
});
