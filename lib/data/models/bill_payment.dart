import 'enums.dart';

/// One payable service inside a provider entry of the bill catalogue
/// (spec §6.2 — `CustomerBillCatalogResponse.services[]`).
class BillService {
  const BillService({
    required this.serviceId,
    required this.name,
    required this.code,
    required this.category,
    this.minAmount,
    this.maxAmount,
  });

  final String serviceId;
  final String name;
  final String code;
  final String category; // ELECTRICITY | WATER | TV | TELECOM | AIRTIME | INTERNET | OTHER
  final int? minAmount;
  final int? maxAmount;

  factory BillService.fromJson(Map<String, dynamic> json) => BillService(
        serviceId: (json['serviceId'] ?? '') as String,
        name: (json['name'] ?? '') as String,
        code: (json['code'] ?? '') as String,
        category: (json['category'] ?? 'OTHER') as String,
        minAmount: json['minAmount'] as int?,
        maxAmount: json['maxAmount'] as int?,
      );
}

/// One provider entry of the payable catalogue
/// (spec §6.2 — `CustomerBillCatalogResponse`). Only ACTIVE providers with at
/// least one ACTIVE service ever appear; the per-provider reference rules and
/// the display-only processing window ride alongside.
class BillCatalogProvider {
  const BillCatalogProvider({
    required this.providerId,
    required this.providerName,
    required this.providerCode,
    required this.supportsReferenceValidation,
    required this.services,
    this.referenceRegex,
    this.referenceMinLength,
    this.referenceMaxLength,
    this.referenceExample,
    this.announcedDelayHours,
    this.processingHoursStart,
    this.processingHoursEnd,
    this.processingDays,
  });

  final String providerId;
  final String providerName;
  final String providerCode;
  final bool supportsReferenceValidation;
  final List<BillService> services;
  final String? referenceRegex;
  final int? referenceMinLength;
  final int? referenceMaxLength;
  final String? referenceExample;
  final int? announcedDelayHours;
  final String? processingHoursStart;
  final String? processingHoursEnd;
  final String? processingDays;

  factory BillCatalogProvider.fromJson(Map<String, dynamic> json) =>
      BillCatalogProvider(
        providerId: (json['providerId'] ?? '') as String,
        providerName: (json['providerName'] ?? '') as String,
        providerCode: (json['providerCode'] ?? '') as String,
        supportsReferenceValidation:
            (json['supportsReferenceValidation'] ?? false) as bool,
        services: (json['services'] is List)
            ? (json['services'] as List)
                .whereType<Map<String, dynamic>>()
                .map(BillService.fromJson)
                .toList(growable: false)
            : const [],
        referenceRegex: json['referenceRegex'] as String?,
        referenceMinLength: json['referenceMinLength'] as int?,
        referenceMaxLength: json['referenceMaxLength'] as int?,
        referenceExample: json['referenceExample'] as String?,
        announcedDelayHours: json['announcedDelayHours'] as int?,
        processingHoursStart: json['processingHoursStart'] as String?,
        processingHoursEnd: json['processingHoursEnd'] as String?,
        processingDays: json['processingDays'] as String?,
      );

  /// Client-side reference pre-check (convenience only — the server is
  /// authoritative, see spec §6.2). Returns true when the entered reference
  /// passes the provider's declared rules (or when no rules are declared).
  bool referenceLooksValid(String reference) {
    if (referenceMinLength != null && reference.length < referenceMinLength!) {
      return false;
    }
    if (referenceMaxLength != null && reference.length > referenceMaxLength!) {
      return false;
    }
    if (referenceRegex != null && referenceRegex!.isNotEmpty) {
      try {
        if (!RegExp(referenceRegex!).hasMatch(reference)) return false;
      } catch (_) {
        // A malformed server regex must not block the user — let the server decide.
      }
    }
    return true;
  }
}

/// BillPaymentResponse (spec §7.4) — the initiation result. Mirrors the P2P
/// control-gate shape: executed (financial fields) vs control-fired (202).
class BillPaymentResult {
  const BillPaymentResult({
    required this.outcome,
    required this.requestedAmount,
    this.matchedThresholdAmount,
    this.billPaymentId,
    this.status,
    this.feeAmount,
    this.netAmount,
    this.transactionId,
    this.createdAt,
  });

  final ControlOutcome outcome;
  final int requestedAmount;
  final int? matchedThresholdAmount;
  final String? billPaymentId;
  final BillPaymentStatus? status;
  final int? feeAmount;
  final int? netAmount;
  final String? transactionId;
  final DateTime? createdAt;

  bool get isExecuted => outcome == ControlOutcome.executed;
  bool get needsPin => outcome == ControlOutcome.pendingPin;
  bool get needsConfirmation => outcome == ControlOutcome.pendingConfirmation;

  factory BillPaymentResult.fromJson(Map<String, dynamic> json) =>
      BillPaymentResult(
        outcome: ControlOutcome.parse(json['outcome'] as String?),
        requestedAmount: (json['requestedAmount'] ?? 0) as int,
        matchedThresholdAmount: json['matchedThresholdAmount'] as int?,
        billPaymentId: json['billPaymentId'] as String?,
        status: json['status'] != null
            ? BillPaymentStatus.parse(json['status'] as String?)
            : null,
        feeAmount: json['feeAmount'] as int?,
        netAmount: json['netAmount'] as int?,
        transactionId: json['transactionId'] as String?,
        createdAt: json['createdAt'] is String
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}

/// CustomerBillPaymentResponse (spec §7.4a) — the filtered customer view used
/// for history + detail timeline. `netAmount` is derived client-side.
class CustomerBillPayment {
  const CustomerBillPayment({
    required this.id,
    required this.providerName,
    required this.reference,
    required this.amount,
    required this.feeAmount,
    required this.status,
    required this.createdAt,
    this.providerLogo,
    this.queuedAt,
    this.processingStartedAt,
    this.completedAt,
    this.externalReference,
    this.refundReason,
  });

  final String id;
  final String providerName;
  final String reference;
  final int amount;
  final int feeAmount;
  final BillPaymentStatus status;
  final DateTime createdAt;
  final String? providerLogo;
  final DateTime? queuedAt;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final String? externalReference;
  final String? refundReason;

  int get netAmount => amount - feeAmount;

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory CustomerBillPayment.fromJson(Map<String, dynamic> json) =>
      CustomerBillPayment(
        id: (json['id'] ?? '') as String,
        providerName: (json['providerName'] ?? '') as String,
        reference: (json['reference'] ?? '') as String,
        amount: (json['amount'] ?? 0) as int,
        feeAmount: (json['feeAmount'] ?? 0) as int,
        status: BillPaymentStatus.parse(json['status'] as String?),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
        providerLogo: json['providerLogo'] as String?,
        queuedAt: _date(json['queuedAt']),
        processingStartedAt: _date(json['processingStartedAt']),
        completedAt: _date(json['completedAt']),
        externalReference: json['externalReference'] as String?,
        refundReason: json['refundReason'] as String?,
      );
}

/// BillPaymentReceiptResponse (spec §7.4a) — JSON receipt, rendered in-app.
class BillPaymentReceipt {
  const BillPaymentReceipt({
    required this.paymentId,
    required this.providerName,
    required this.amount,
    required this.feeAmount,
    required this.reference,
    required this.completedAt,
    this.externalReference,
    this.operatorCode,
  });

  final String paymentId;
  final String providerName;
  final int amount;
  final int feeAmount;
  final String reference;
  final DateTime completedAt;
  final String? externalReference;
  final String? operatorCode;

  int get netAmount => amount - feeAmount;

  factory BillPaymentReceipt.fromJson(Map<String, dynamic> json) =>
      BillPaymentReceipt(
        paymentId: (json['paymentId'] ?? '') as String,
        providerName: (json['providerName'] ?? '') as String,
        amount: (json['amount'] ?? 0) as int,
        feeAmount: (json['feeAmount'] ?? 0) as int,
        reference: (json['reference'] ?? '') as String,
        completedAt: json['completedAt'] is String
            ? (DateTime.tryParse(json['completedAt'] as String) ??
                DateTime.now())
            : DateTime.now(),
        externalReference: json['externalReference'] as String?,
        operatorCode: json['operatorCode'] as String?,
      );
}
