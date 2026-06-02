import 'enums.dart';

/// CustomerCardResponse (spec §7.3). Never exposes full PAN / nfcUid / keys.
class CustomerCard {
  const CustomerCard({
    required this.id,
    required this.cardType,
    required this.status,
    required this.pinEnabled,
    required this.expiresAt,
    required this.issuedAt,
    this.internalCardLast4,
    this.maskedInternalCardNumber,
    this.activatedAt,
    this.lastUsedAt,
    this.replacedByCardId,
  });

  final String id;
  final String cardType; // CardType enum string
  final CardStatus status;
  final bool pinEnabled;
  final DateTime expiresAt; // local date
  final DateTime issuedAt;
  final String? internalCardLast4;
  final String? maskedInternalCardNumber;
  final DateTime? activatedAt;
  final DateTime? lastUsedAt;
  final String? replacedByCardId;

  String get last4 => internalCardLast4 ?? '••••';

  factory CustomerCard.fromJson(Map<String, dynamic> json) => CustomerCard(
        id: json['id'] as String,
        cardType: (json['cardType'] ?? 'STANDARD') as String,
        status: CardStatus.parse(json['status'] as String?),
        pinEnabled: (json['pinEnabled'] ?? false) as bool,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        issuedAt: DateTime.parse((json['issuedAt'] ?? json['expiresAt']) as String),
        internalCardLast4:
            (json['internalCardLast4'] ?? json['last4']) as String?,
        maskedInternalCardNumber: json['maskedInternalCardNumber'] as String?,
        activatedAt: _opt(json['activatedAt']),
        lastUsedAt: _opt(json['lastUsedAt']),
        replacedByCardId: json['replacedByCardId'] as String?,
      );

  static DateTime? _opt(Object? v) => v is String ? DateTime.tryParse(v) : null;
}
