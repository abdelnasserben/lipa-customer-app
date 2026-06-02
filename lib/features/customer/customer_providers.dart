import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/bill_payment.dart';
import '../../data/models/card.dart';
import '../../data/models/customer_profile.dart';
import '../../data/models/notification.dart';
import '../../data/models/transaction.dart';
import '../../data/repositories/customer_repository.dart';

// Profile / balance / limits are `autoDispose`: they tear down when the
// customer shell unmounts at logout, so they never refetch under a cleared
// token (which would 401 and then leave a stuck error cached) and always
// start fresh for the next user on re-login. See SessionController.
final profileProvider = FutureProvider.autoDispose<CustomerProfile>((ref) {
  return ref.watch(customerRepositoryProvider).getProfile();
});

final balanceProvider = FutureProvider.autoDispose<CustomerBalance>((ref) {
  return ref.watch(customerRepositoryProvider).getBalance();
});

/// Null when no limit profile is assigned (404 → "not configured").
final limitsProvider = FutureProvider.autoDispose<CustomerLimits?>((ref) {
  return ref.watch(customerRepositoryProvider).getLimits();
});

final activityProvider =
    FutureProvider.autoDispose<List<CustomerTransaction>>((ref) {
  return ref.watch(customerRepositoryProvider).getActivity(limit: 10);
});

final transactionsProvider =
    FutureProvider.autoDispose<List<CustomerTransaction>>((ref) async {
  final page = await ref.watch(customerRepositoryProvider).getTransactions();
  return page.items;
});

final beneficiariesProvider =
    FutureProvider.autoDispose<List<Beneficiary>>((ref) {
  return ref.watch(customerRepositoryProvider).getBeneficiaries();
});

final cardsProvider = FutureProvider.autoDispose<List<CustomerCard>>((ref) {
  return ref.watch(customerRepositoryProvider).getCards();
});

/// Unread badge count — refreshed on demand.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(customerRepositoryProvider).getUnreadCount();
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) {
  return ref.watch(customerRepositoryProvider).getNotifications();
});

/// Ledger statement (most recent window). Re-fetched on demand.
final statementsProvider =
    FutureProvider.autoDispose<List<StatementEntry>>((ref) async {
  final page = await ref.watch(customerRepositoryProvider).getStatements();
  return page.items;
});

/// Bill-pay feature probe (spec §10.5): the catalogue 404 → feature off, which
/// surfaces as [BillPayDisabledException] and resolves here to an empty list.
/// `hasData && isNotEmpty` ⇒ show the bill-pay entry point.
final billCatalogueProvider =
    FutureProvider.autoDispose<List<BillCatalogProvider>>((ref) async {
  try {
    return await ref.watch(customerRepositoryProvider).getBillCatalogue();
  } on BillPayDisabledException {
    return const [];
  }
});

/// True when bill payment is enabled AND at least one provider is payable.
final billPayEnabledProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(billCatalogueProvider).maybeWhen(
        data: (list) => list.isNotEmpty,
        orElse: () => false,
      );
});

/// The caller's bill payments (history), newest first.
final billPaymentsProvider =
    FutureProvider.autoDispose<List<CustomerBillPayment>>((ref) async {
  final page = await ref.watch(customerRepositoryProvider).getBillPayments();
  return page.items;
});

/// One bill payment, re-fetched by id (drives the detail timeline).
final billPaymentProvider = FutureProvider.autoDispose
    .family<CustomerBillPayment, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getBillPayment(id);
});
