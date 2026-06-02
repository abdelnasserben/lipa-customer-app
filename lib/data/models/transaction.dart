import 'enums.dart';

/// CustomerTransactionResponse (spec §7.3).
///
/// The wire DTO is wallet-scoped but doesn't carry a `dir`/`label`. We derive
/// direction from whether the source wallet is the caller's, and a display
/// label from type + counterparty when available.
class CustomerTransaction {
  const CustomerTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.requestedAmount,
    required this.feeAmount,
    required this.netAmountToDestination,
    required this.createdAt,
    this.sourceWalletId,
    this.destinationWalletId,
    this.declineReason,
    this.completedAt,
    this.declinedAt,
    this.isIncoming = false,
    this.counterparty,
    this.label,
  });

  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final int requestedAmount;
  final int feeAmount;
  final int netAmountToDestination;
  final DateTime createdAt;
  final String? sourceWalletId;
  final String? destinationWalletId;
  final String? declineReason;
  final DateTime? completedAt;
  final DateTime? declinedAt;

  /// Derived presentation fields.
  final bool isIncoming;
  final String? counterparty;
  final String? label;

  /// Parses the wire DTO. [walletId] (the caller's wallet) lets us compute
  /// direction by comparing it against the source/destination wallets.
  factory CustomerTransaction.fromJson(
    Map<String, dynamic> json, {
    String? walletId,
  }) {
    final src = json['sourceWalletId'] as String?;
    final dst = json['destinationWalletId'] as String?;
    final incoming =
        walletId != null && dst == walletId && src != walletId;
    return CustomerTransaction(
      id: json['id'] as String,
      type: TransactionType.parse(json['type'] as String?),
      status: TransactionStatus.parse(json['status'] as String?),
      requestedAmount: (json['requestedAmount'] ?? json['amount'] ?? 0) as int,
      feeAmount: (json['feeAmount'] ?? json['fee'] ?? 0) as int,
      netAmountToDestination:
          (json['netAmountToDestination'] ?? json['net'] ?? 0) as int,
      createdAt: DateTime.parse((json['createdAt'] ?? json['ts']) as String),
      sourceWalletId: src,
      destinationWalletId: dst,
      declineReason: json['declineReason'] as String?,
      completedAt: _parseOpt(json['completedAt']),
      declinedAt: _parseOpt(json['declinedAt']),
      isIncoming: incoming,
      counterparty: json['counterparty'] as String?,
      label: json['label'] as String?,
    );
  }

  static DateTime? _parseOpt(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}

/// CustomerStatementEntryResponse (spec §7.3).
class StatementEntry {
  const StatementEntry({
    required this.id,
    required this.transactionId,
    required this.entryType,
    required this.amount,
    required this.runningBalance,
    required this.description,
    required this.postedAt,
  });

  final String id;
  final String transactionId;
  final EntryType entryType;
  final int amount;
  final int runningBalance;
  final String description;
  final DateTime postedAt;

  bool get isCredit => entryType.isCredit;

  /// Signed amount: credits add, debits subtract.
  int get signedAmount => isCredit ? amount : -amount;

  /// Human-facing description. The backend sets [description] to an internal
  /// ledger string that *leads* with the raw transaction-type token followed by
  /// technical detail, e.g. `SERVICE_PAYMENT debit(...)`, `P2P_TRANSFER credit(r...)`.
  /// We map that leading token to its French label (matching the Activités
  /// screen, which labels purely by type) and drop the technical remainder.
  /// Free text with no recognizable leading token passes through untouched.
  String get displayDescription {
    final raw = description.trim();
    final t = _leadingType(raw);
    if (t != null && t != TransactionType.unknown) return t.frLabel;
    return raw.isEmpty ? 'Transaction' : raw;
  }

  /// Parses the leading SCREAMING_SNAKE token (the type) from a ledger
  /// description. Returns null when the string doesn't start with such a token.
  static TransactionType? _leadingType(String s) {
    final m = RegExp(r'^([A-Z][A-Z0-9_]*)').firstMatch(s);
    if (m == null) return null;
    return TransactionType.parse(m.group(1));
  }

  factory StatementEntry.fromJson(Map<String, dynamic> json) => StatementEntry(
        id: (json['id'] ?? '') as String,
        transactionId: (json['transactionId'] ?? '') as String,
        entryType: EntryType.parse(json['entryType'] as String?),
        amount: _asInt(json['amount']),
        runningBalance: _asInt(json['runningBalance']),
        description: (json['description'] ?? '') as String,
        postedAt:
            DateTime.tryParse(json['postedAt']?.toString() ?? '') ??
                DateTime.now(),
      );

  /// Tolerates a `long` arriving as int, double, or numeric string.
  static int _asInt(Object? v) => switch (v) {
        int i => i,
        num n => n.round(),
        String s => int.tryParse(s) ?? num.tryParse(s)?.round() ?? 0,
        _ => 0,
      };
}

/// BeneficiaryResponse (spec §7.3).
class Beneficiary {
  const Beneficiary({
    required this.customerId,
    required this.fullName,
    required this.phoneCountryCode,
    required this.phoneNumber,
    this.externalRef,
  });

  final String customerId;
  final String fullName;
  final String phoneCountryCode;
  final String phoneNumber;
  final String? externalRef;

  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  factory Beneficiary.fromJson(Map<String, dynamic> json) => Beneficiary(
        customerId: (json['customerId'] ?? json['id'] ?? '') as String,
        fullName: (json['fullName'] ?? json['name'] ?? '') as String,
        phoneCountryCode: (json['phoneCountryCode'] ?? '269') as String,
        phoneNumber: (json['phoneNumber'] ?? '') as String,
        externalRef: json['externalRef'] as String?,
      );
}
