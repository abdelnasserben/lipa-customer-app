import 'enums.dart';

/// P2pTransferResponse (spec §7.4). Two shapes: executed (financial fields)
/// vs control-fired (only outcome + matchedThresholdAmount).
class P2pTransferResult {
  const P2pTransferResult({
    required this.outcome,
    required this.requestedAmount,
    this.matchedThresholdAmount,
    this.transactionId,
    this.status,
    this.feeAmount,
    this.netAmountToDestination,
    this.completedAt,
    this.replayed,
  });

  final ControlOutcome outcome;
  final int requestedAmount;
  final int? matchedThresholdAmount;
  final String? transactionId;
  final TransactionStatus? status;
  final int? feeAmount;
  final int? netAmountToDestination;
  final DateTime? completedAt;
  final bool? replayed;

  bool get isExecuted => outcome == ControlOutcome.executed;
  bool get needsPin => outcome == ControlOutcome.pendingPin;
  bool get needsConfirmation => outcome == ControlOutcome.pendingConfirmation;

  factory P2pTransferResult.fromJson(Map<String, dynamic> json) =>
      P2pTransferResult(
        outcome: ControlOutcome.parse(json['outcome'] as String?),
        requestedAmount: (json['requestedAmount'] ?? 0) as int,
        matchedThresholdAmount: json['matchedThresholdAmount'] as int?,
        transactionId: json['transactionId'] as String?,
        status: json['status'] != null
            ? TransactionStatus.parse(json['status'] as String?)
            : null,
        feeAmount: json['feeAmount'] as int?,
        netAmountToDestination: json['netAmountToDestination'] as int?,
        completedAt: json['completedAt'] is String
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
        replayed: json['replayed'] as bool?,
      );
}

/// PaymentRequestLookupResponse (spec §7.5) — payer preview.
class PaymentRequestLookup {
  const PaymentRequestLookup({
    required this.amount,
    required this.beneficiaryName,
    required this.feePreview,
    required this.totalToPay,
    required this.expiresAt,
    this.label,
    this.shortCode,
  });

  final int amount;
  final String beneficiaryName;
  final int feePreview;
  final int totalToPay;
  final DateTime expiresAt;
  final String? label;
  final String? shortCode;

  factory PaymentRequestLookup.fromJson(Map<String, dynamic> json) =>
      PaymentRequestLookup(
        amount: (json['amount'] ?? 0) as int,
        beneficiaryName: (json['beneficiaryName'] ?? '') as String,
        feePreview: (json['feePreview'] ?? 0) as int,
        totalToPay: (json['totalToPay'] ?? json['amount'] ?? 0) as int,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        label: json['label'] as String?,
        shortCode: json['shortCode'] as String?,
      );
}

/// PayPaymentRequestResponse (spec §7.5) — payer settlement result.
class PayPaymentRequestResult {
  const PayPaymentRequestResult({
    required this.outcome,
    required this.replayed,
    this.transactionId,
    this.paymentRequestId,
    this.status,
    this.requestedAmount,
    this.feeAmount,
    this.netAmountToDestination,
    this.matchedThresholdAmount,
    this.completedAt,
  });

  final ControlOutcome outcome;
  final bool replayed;
  final String? transactionId;
  final String? paymentRequestId;
  final TransactionStatus? status;
  final int? requestedAmount;
  final int? feeAmount;
  final int? netAmountToDestination;
  final int? matchedThresholdAmount;
  final DateTime? completedAt;

  bool get isExecuted => outcome == ControlOutcome.executed;
  bool get needsPin => outcome == ControlOutcome.pendingPin;
  bool get needsConfirmation => outcome == ControlOutcome.pendingConfirmation;

  factory PayPaymentRequestResult.fromJson(Map<String, dynamic> json) =>
      PayPaymentRequestResult(
        outcome: ControlOutcome.parse(json['outcome'] as String?),
        replayed: (json['replayed'] ?? false) as bool,
        transactionId: json['transactionId'] as String?,
        paymentRequestId: json['paymentRequestId'] as String?,
        status: json['status'] != null
            ? TransactionStatus.parse(json['status'] as String?)
            : null,
        requestedAmount: json['requestedAmount'] as int?,
        feeAmount: json['feeAmount'] as int?,
        netAmountToDestination: json['netAmountToDestination'] as int?,
        matchedThresholdAmount: json['matchedThresholdAmount'] as int?,
        completedAt: json['completedAt'] is String
            ? DateTime.tryParse(json['completedAt'] as String)
            : null,
      );
}
