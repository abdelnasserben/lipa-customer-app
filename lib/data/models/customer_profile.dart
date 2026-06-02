import 'enums.dart';

/// CustomerProfileResponse (spec §7.2).
class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.externalRef,
    required this.fullName,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.kycLevel,
    required this.status,
    this.walletId,
    this.limitProfileId,
    this.addressIsland,
    this.addressCity,
    this.addressDistrict,
  });

  final String id;
  final String externalRef;
  final String fullName;
  final String phoneCountryCode;
  final String phoneNumber;
  final String kycLevel;
  final CustomerStatus status;
  final String? walletId;
  final String? limitProfileId;
  final String? addressIsland;
  final String? addressCity;
  final String? addressDistrict;

  /// "SA" — initials for the avatar.
  String get initials {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool get isKycVerified =>
      kycLevel == 'KYC_VERIFIED' || kycLevel == 'KYC_ENHANCED';

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        id: json['id'] as String,
        externalRef: (json['externalRef'] ?? '') as String,
        fullName: (json['fullName'] ?? '') as String,
        phoneCountryCode: (json['phoneCountryCode'] ?? '') as String,
        phoneNumber: (json['phoneNumber'] ?? '') as String,
        kycLevel: (json['kycLevel'] ?? 'KYC_NONE') as String,
        status: CustomerStatus.parse(json['status'] as String?),
        walletId: json['walletId'] as String?,
        limitProfileId: json['limitProfileId'] as String?,
        addressIsland: json['addressIsland'] as String?,
        addressCity: json['addressCity'] as String?,
        addressDistrict: json['addressDistrict'] as String?,
      );
}

/// CustomerBalanceResponse (spec §7.2).
class CustomerBalance {
  const CustomerBalance({
    required this.walletId,
    required this.availableBalance,
    required this.frozenBalance,
    required this.walletStatus,
  });

  final String walletId;
  final int availableBalance;
  final int frozenBalance;
  final WalletStatus walletStatus;

  factory CustomerBalance.fromJson(Map<String, dynamic> json) =>
      CustomerBalance(
        walletId: (json['walletId'] ?? '') as String,
        availableBalance: (json['availableBalance'] ?? 0) as int,
        frozenBalance: (json['frozenBalance'] ?? 0) as int,
        walletStatus: WalletStatus.parse(json['walletStatus'] as String?),
      );
}

/// CustomerLimitsResponse (spec §7.2). All bounds are optional.
class CustomerLimits {
  const CustomerLimits({
    required this.limitProfileId,
    required this.profileName,
    this.maxTransactionAmount,
    this.maxDailyAmount,
    this.maxMonthlyAmount,
    this.maxDailyTransactionCount,
    this.requiredKycLevel,
  });

  final String limitProfileId;
  final String profileName;
  final int? maxTransactionAmount;
  final int? maxDailyAmount;
  final int? maxMonthlyAmount;
  final int? maxDailyTransactionCount;
  final String? requiredKycLevel;

  factory CustomerLimits.fromJson(Map<String, dynamic> json) => CustomerLimits(
        limitProfileId: (json['limitProfileId'] ?? '') as String,
        profileName: (json['profileName'] ?? '') as String,
        maxTransactionAmount: json['maxTransactionAmount'] as int?,
        maxDailyAmount: json['maxDailyAmount'] as int?,
        maxMonthlyAmount: json['maxMonthlyAmount'] as int?,
        maxDailyTransactionCount: json['maxDailyTransactionCount'] as int?,
        requiredKycLevel: json['requiredKycLevel'] as String?,
      );
}
