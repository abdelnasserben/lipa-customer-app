import 'package:uuid/uuid.dart';

import '../../core/error/api_error.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_envelopes.dart';
import '../models/bill_payment.dart';
import '../models/card.dart';
import '../models/customer_profile.dart';
import '../models/notification.dart';
import '../models/transaction.dart';
import '../models/transfer_result.dart';

/// Raised when a bill-payment route returns 404 because `billpay.enabled=false`
/// (spec §1.1 / §10.5). The UI hides the bill-pay feature entirely on this —
/// it is **not** a generic error to surface to the user.
class BillPayDisabledException implements Exception {
  const BillPayDisabledException();
  @override
  String toString() => 'BillPayDisabledException';
}

/// Customer portal surface (spec §5.2 / §5.3). Implementation:
/// [ApiCustomerRepository].
abstract class CustomerRepository {
  Future<CustomerProfile> getProfile();
  Future<CustomerBalance> getBalance();

  /// Returns null when no limit profile is assigned (spec maps 404 → "limits
  /// not configured", not an error).
  Future<CustomerLimits?> getLimits();

  Future<List<CustomerTransaction>> getActivity({int limit = 10});
  Future<PagedResponse<CustomerTransaction>> getTransactions({String? cursor});
  Future<CustomerTransaction> getTransaction(String id);

  /// Ledger statement, newest first (spec §5.2). Optional ISO `from`/`to`
  /// date window (`YYYY-MM-DD`) and opaque cursor paging.
  Future<PagedResponse<StatementEntry>> getStatements({
    String? cursor,
    String? from,
    String? to,
  });

  Future<List<Beneficiary>> getBeneficiaries({int limit = 20});

  Future<List<CustomerCard>> getCards();
  Future<CustomerCard> getCard(String id);
  Future<CustomerCard> reportCardLost(String id);
  Future<CustomerCard> reportCardStolen(String id);

  /// Sends a P2P transfer. On a 202 control gate, pass [pin] or
  /// [confirmationAcknowledged] on the resubmit while reusing [idempotencyKey].
  Future<P2pTransferResult> sendP2p({
    required String idempotencyKey,
    required String recipientCountryCode,
    required String recipientPhone,
    required int amount,
    String? description,
    String? pin,
    bool? confirmationAcknowledged,
  });

  Future<PaymentRequestLookup> lookupPaymentRequest(String shortCode);
  Future<PayPaymentRequestResult> payPaymentRequest({
    required String shortCode,
    required String idempotencyKey,
    String? pin,
    bool? confirmationAcknowledged,
  });

  // ── Bill payment (spec §5.2 / §5.2a) ────────────────────────────────────
  // Every bill-pay call throws [BillPayDisabledException] on a 404 when
  // `billpay.enabled=false` — the UI hides the feature on that.

  /// Payable catalogue: active providers + their active services.
  Future<List<BillCatalogProvider>> getBillCatalogue();

  /// Initiates a bill payment. Mirrors the P2P 202 control gate: on a 202,
  /// resubmit with the same [idempotencyKey] and [pin] / [confirmationAcknowledged].
  Future<BillPaymentResult> initiateBillPayment({
    required String idempotencyKey,
    required String serviceId,
    required String reference,
    required int amount,
    String? pin,
    bool? confirmationAcknowledged,
  });

  /// Caller's bill payments, newest first (offset paging: [page]/[size]).
  Future<PagedResponse<CustomerBillPayment>> getBillPayments({
    int page = 0,
    String? status,
  });

  Future<CustomerBillPayment> getBillPayment(String id);

  /// Receipt — only valid when the payment is SUCCEEDED (404 otherwise).
  Future<BillPaymentReceipt> getBillPaymentReceipt(String id);

  /// Cancels a QUEUED bill payment, refunding the held funds.
  Future<CustomerBillPayment> cancelBillPayment(String id);

  // Notifications (shared inbox).
  Future<List<AppNotification>> getNotifications({int limit = 20});
  Future<int> getUnreadCount();
  Future<void> markNotificationRead(String id);
  Future<int> markAllNotificationsRead();
}

/// Generates a fresh idempotency key per new financial intent.
String newIdempotencyKey() => const Uuid().v4();

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(this._api);

  final ApiClient _api;
  static const _base = '/api/v1/me';
  static const _notif = '/api/v1/notifications';

  String? _walletId; // cached for transaction-direction derivation

  @override
  Future<CustomerProfile> getProfile() async {
    final res = await _api.get(_base);
    final profile =
        unwrapData(res.data, (d) => CustomerProfile.fromJson(d as Map<String, dynamic>));
    _walletId = profile.walletId;
    return profile;
  }

  @override
  Future<CustomerBalance> getBalance() async {
    final res = await _api.get('$_base/balance');
    final b = unwrapData(
        res.data, (d) => CustomerBalance.fromJson(d as Map<String, dynamic>));
    _walletId ??= b.walletId;
    return b;
  }

  @override
  Future<CustomerLimits?> getLimits() async {
    try {
      final res = await _api.get('$_base/limits');
      return unwrapData(
          res.data, (d) => CustomerLimits.fromJson(d as Map<String, dynamic>));
    } catch (e) {
      // 404 → no profile assigned (spec §11.4): treat as "not configured".
      return null;
    }
  }

  @override
  Future<List<CustomerTransaction>> getActivity({int limit = 10}) async {
    final res = await _api.get('$_base/activity', query: {'limit': limit});
    return parseDataList(
        res.data, (m) => CustomerTransaction.fromJson(m, walletId: _walletId));
  }

  @override
  Future<PagedResponse<CustomerTransaction>> getTransactions(
      {String? cursor}) async {
    final res = await _api.get('$_base/transactions',
        query: {if (cursor != null) 'cursor': cursor});
    return PagedResponse.fromBody(
        res.data, (m) => CustomerTransaction.fromJson(m, walletId: _walletId));
  }

  @override
  Future<CustomerTransaction> getTransaction(String id) async {
    final res = await _api.get('$_base/transactions/$id');
    return unwrapData(res.data,
        (d) => CustomerTransaction.fromJson(d as Map<String, dynamic>, walletId: _walletId));
  }

  @override
  Future<PagedResponse<StatementEntry>> getStatements({
    String? cursor,
    String? from,
    String? to,
  }) async {
    final res = await _api.get('$_base/statements', query: {
      if (cursor != null) 'cursor': cursor,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return PagedResponse.fromBody(res.data, StatementEntry.fromJson);
  }

  @override
  Future<List<Beneficiary>> getBeneficiaries({int limit = 20}) async {
    final res = await _api.get('$_base/beneficiaries', query: {'limit': limit});
    return parseDataList(res.data, Beneficiary.fromJson);
  }

  @override
  Future<List<CustomerCard>> getCards() async {
    final res = await _api.get('$_base/cards');
    return parseDataList(res.data, CustomerCard.fromJson);
  }

  @override
  Future<CustomerCard> getCard(String id) async {
    final res = await _api.get('$_base/cards/$id');
    return unwrapData(
        res.data, (d) => CustomerCard.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<CustomerCard> reportCardLost(String id) =>
      _reportCard(id, 'report-lost');

  @override
  Future<CustomerCard> reportCardStolen(String id) =>
      _reportCard(id, 'report-stolen');

  Future<CustomerCard> _reportCard(String id, String action) async {
    final res = await _api.post('$_base/cards/$id/$action');
    return unwrapData(
        res.data, (d) => CustomerCard.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<P2pTransferResult> sendP2p({
    required String idempotencyKey,
    required String recipientCountryCode,
    required String recipientPhone,
    required int amount,
    String? description,
    String? pin,
    bool? confirmationAcknowledged,
  }) async {
    final res = await _api.post(
      '$_base/p2p',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'recipientCountryCode': recipientCountryCode,
        'recipientPhone': recipientPhone,
        'amount': amount,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (pin != null) 'pin': pin,
        if (confirmationAcknowledged != null)
          'confirmationAcknowledged': confirmationAcknowledged,
      },
    );
    return unwrapData(
        res.data, (d) => P2pTransferResult.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<PaymentRequestLookup> lookupPaymentRequest(String shortCode) async {
    final res = await _api.get('$_base/payment-requests/lookup/$shortCode');
    final lookup = unwrapData(res.data,
        (d) => PaymentRequestLookup.fromJson(d as Map<String, dynamic>));
    return lookup;
  }

  @override
  Future<PayPaymentRequestResult> payPaymentRequest({
    required String shortCode,
    required String idempotencyKey,
    String? pin,
    bool? confirmationAcknowledged,
  }) async {
    final res = await _api.post(
      '$_base/payment-requests/$shortCode/pay',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        if (pin != null) 'pin': pin,
        if (confirmationAcknowledged != null)
          'confirmationAcknowledged': confirmationAcknowledged,
      },
    );
    return unwrapData(res.data,
        (d) => PayPaymentRequestResult.fromJson(d as Map<String, dynamic>));
  }

  // ── Bill payment ────────────────────────────────────────────────────────

  /// Runs a bill-pay request, translating a 404 (feature off) into the typed
  /// [BillPayDisabledException] so callers can hide the feature (spec §10.5).
  Future<T> _billPay<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ApiError catch (e) {
      if (e.isNotFound) throw const BillPayDisabledException();
      rethrow;
    }
  }

  @override
  Future<List<BillCatalogProvider>> getBillCatalogue() => _billPay(() async {
        final res = await _api.get('$_base/bill-payments/services');
        return parseDataList(res.data, BillCatalogProvider.fromJson);
      });

  @override
  Future<BillPaymentResult> initiateBillPayment({
    required String idempotencyKey,
    required String serviceId,
    required String reference,
    required int amount,
    String? pin,
    bool? confirmationAcknowledged,
  }) =>
      _billPay(() async {
        final res = await _api.post(
          '$_base/bill-payments',
          headers: {'Idempotency-Key': idempotencyKey},
          body: {
            'serviceId': serviceId,
            'reference': reference,
            'amount': amount,
            if (pin != null) 'pin': pin,
            if (confirmationAcknowledged != null)
              'confirmationAcknowledged': confirmationAcknowledged,
          },
        );
        return unwrapData(res.data,
            (d) => BillPaymentResult.fromJson(d as Map<String, dynamic>));
      });

  @override
  Future<PagedResponse<CustomerBillPayment>> getBillPayments({
    int page = 0,
    String? status,
  }) =>
      _billPay(() async {
        final res = await _api.get('$_base/bill-payments', query: {
          'page': page,
          if (status != null) 'status': status,
        });
        return PagedResponse.fromBody(
            res.data, CustomerBillPayment.fromJson);
      });

  // For detail/receipt/cancel a 404 is ambiguous (feature off **or** not the
  // caller's payment / not SUCCEEDED). These screens are only reachable once
  // the catalogue probe confirmed the feature is on, so we let the 404 through
  // as a normal ApiError and let the UI show "Introuvable".

  @override
  Future<CustomerBillPayment> getBillPayment(String id) async {
    final res = await _api.get('$_base/bill-payments/$id');
    return unwrapData(
        res.data, (d) => CustomerBillPayment.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<BillPaymentReceipt> getBillPaymentReceipt(String id) async {
    final res = await _api.get('$_base/bill-payments/$id/receipt');
    return unwrapData(
        res.data, (d) => BillPaymentReceipt.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<CustomerBillPayment> cancelBillPayment(String id) async {
    final res = await _api.post('$_base/bill-payments/$id/cancel');
    return unwrapData(
        res.data, (d) => CustomerBillPayment.fromJson(d as Map<String, dynamic>));
  }

  @override
  Future<List<AppNotification>> getNotifications({int limit = 20}) async {
    final res = await _api.get(_notif, query: {'limit': limit});
    return parseDataList(res.data, AppNotification.fromJson);
  }

  @override
  Future<int> getUnreadCount() async {
    final res = await _api.get('$_notif/unread');
    return unwrapData(res.data, (d) {
      if (d is Map<String, dynamic>) return (d['unread'] ?? 0) as int;
      return 0;
    });
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _api.post('$_notif/$id/read');
  }

  @override
  Future<int> markAllNotificationsRead() async {
    final res = await _api.post('$_notif/read-all');
    return unwrapData(res.data, (d) {
      if (d is Map<String, dynamic>) return (d['updated'] ?? 0) as int;
      return 0;
    });
  }
}
