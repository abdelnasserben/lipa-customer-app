import 'dart:convert';

import 'enums.dart';

/// NotificationResponse (spec §7.6). `title`/`body` are pre-rendered French.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.data,
    this.readAt,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String body;
  final NotificationStatus status;
  final DateTime createdAt;

  /// Raw JSON string payload — parse for deep-link params (§7.6).
  final String? data;
  final DateTime? readAt;

  /// Extracts `transactionId` for TRANSACTION rows.
  String? get transactionId => _payload()['transactionId'] as String?;

  /// Extracts `billPaymentId` for BILL_PAYMENT rows.
  String? get billPaymentId => _payload()['billPaymentId'] as String?;

  Map<String, dynamic> _payload() {
    if (data == null) return const {};
    try {
      final decoded = jsonDecode(data!);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  AppNotification copyWith({NotificationStatus? status, DateTime? readAt}) =>
      AppNotification(
        id: id,
        category: category,
        title: title,
        body: body,
        status: status ?? this.status,
        createdAt: createdAt,
        data: data,
        readAt: readAt ?? this.readAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        category: NotificationCategory.parse(json['category'] as String?),
        title: (json['title'] ?? '') as String,
        body: (json['body'] ?? '') as String,
        status: NotificationStatus.parse(json['status'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        data: json['data'] as String?,
        readAt: json['readAt'] is String
            ? DateTime.tryParse(json['readAt'] as String)
            : null,
      );
}
