import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../data/models/bill_payment.dart';
import '../../data/repositories/customer_repository.dart';
import '../customer/customer_providers.dart';

/// Phase of the bill-payment initiation control-gate loop (spec §10.5).
enum BillPayPhase {
  idle,
  submitting,
  needsConfirmation,
  needsPin,
  executed,
  error,
}

class BillPayState {
  const BillPayState({
    this.phase = BillPayPhase.idle,
    this.result,
    this.errorMessage,
    this.matchedThreshold,
  });

  final BillPayPhase phase;
  final BillPaymentResult? result;
  final String? errorMessage;
  final int? matchedThreshold;

  BillPayState copyWith({
    BillPayPhase? phase,
    BillPaymentResult? result,
    String? errorMessage,
    int? matchedThreshold,
    bool clearError = false,
  }) =>
      BillPayState(
        phase: phase ?? this.phase,
        result: result ?? this.result,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        matchedThreshold: matchedThreshold ?? this.matchedThreshold,
      );
}

/// Drives the bill-payment 202 control-gate loop. One intent reuses a single
/// [idempotencyKey] across the confirmation/PIN resubmits (spec §2.4).
class BillPayController extends StateNotifier<BillPayState> {
  BillPayController(
    this._ref, {
    required this.serviceId,
    required this.reference,
    required this.amount,
  })  : _idempotencyKey = newIdempotencyKey(),
        super(const BillPayState());

  final Ref _ref;
  final String serviceId;
  final String reference;
  final int amount;

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
    state = state.copyWith(phase: BillPayPhase.submitting, clearError: true);
    try {
      final res = await _repo.initiateBillPayment(
        idempotencyKey: _idempotencyKey,
        serviceId: serviceId,
        reference: reference,
        amount: amount,
        pin: pin,
        confirmationAcknowledged: _confirmationAcknowledged ? true : null,
      );
      if (res.isExecuted) {
        // The wallet moved and a new queued payment exists.
        _ref.invalidate(balanceProvider);
        _ref.invalidate(activityProvider);
        _ref.invalidate(billPaymentsProvider);
        _ref.invalidate(unreadCountProvider);
        state = state.copyWith(phase: BillPayPhase.executed, result: res);
      } else if (res.needsConfirmation) {
        state = state.copyWith(
          phase: BillPayPhase.needsConfirmation,
          result: res,
          matchedThreshold: res.matchedThresholdAmount,
        );
      } else if (res.needsPin) {
        state = state.copyWith(phase: BillPayPhase.needsPin, result: res);
      } else {
        state = state.copyWith(
            phase: BillPayPhase.error,
            errorMessage: 'Réponse inattendue du serveur.');
      }
    } on ApiError catch (e) {
      state = state.copyWith(
          phase: BillPayPhase.error, errorMessage: frenchMessageForError(e));
    } on BillPayDisabledException {
      state = state.copyWith(
          phase: BillPayPhase.error,
          errorMessage: 'Le paiement de factures est indisponible.');
    } catch (_) {
      state = state.copyWith(
          phase: BillPayPhase.error, errorMessage: 'Une erreur est survenue.');
    }
  }
}

/// Identifies a single bill-payment intent.
class BillPayArgs {
  const BillPayArgs({
    required this.serviceId,
    required this.reference,
    required this.amount,
  });
  final String serviceId;
  final String reference;
  final int amount;
}

final billPayControllerProvider = StateNotifierProvider.autoDispose
    .family<BillPayController, BillPayState, BillPayArgs>((ref, args) {
  return BillPayController(
    ref,
    serviceId: args.serviceId,
    reference: args.reference,
    amount: args.amount,
  );
});
