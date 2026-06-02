import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/notification.dart';
import '../activity/transaction_detail_screen.dart';
import '../bills/bill_detail_screen.dart';
import '../customer/customer_providers.dart';

/// Notifications inbox (design: customer.jsx NotificationsScreen; spec §10.6).
///
/// Marks a row read optimistically on tap, then deep-links by category.
/// Pull-to-refresh refetches; "Tout marquer lu" calls read-all.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<AppNotification>? _local;

  List<AppNotification> get _items => _local ?? const [];
  int get _unread => _items.where((n) => n.status.isUnread).length;

  Future<void> _markAll() async {
    final repo = ref.read(customerRepositoryProvider);
    setState(() {
      _local = _items
          .map((n) => n.copyWith(
              status: NotificationStatus.read, readAt: DateTime.now()))
          .toList();
    });
    await repo.markAllNotificationsRead();
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _open(AppNotification n) async {
    final repo = ref.read(customerRepositoryProvider);
    // Optimistic flip.
    setState(() {
      _local = _items
          .map((x) => x.id == n.id
              ? x.copyWith(status: NotificationStatus.read)
              : x)
          .toList();
    });
    repo.markNotificationRead(n.id).then((_) {
      ref.invalidate(unreadCountProvider);
    });

    if (n.category == NotificationCategory.transaction &&
        n.transactionId != null) {
      try {
        final tx = await repo.getTransaction(n.transactionId!);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(tx: tx)),
          );
        }
      } catch (_) {/* not found → just dismiss */}
    } else if (n.category == NotificationCategory.billPayment &&
        n.billPaymentId != null) {
      // Deep-link to the bill-payment tracking screen (spec §10.6).
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => BillDetailScreen(id: n.billPaymentId!)),
      );
    }
    // Unknown category/type → no deep-link, just dismiss.
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);
    // Seed local state from the provider once loaded.
    async.whenData((data) {
      _local ??= data;
    });

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Notifications',
              onBack: () => Navigator.pop(context),
              action: _unread > 0
                  ? TextButton(
                      onPressed: _markAll,
                      child: Text('Tout marquer lu',
                          style: AppText.ui(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.brandDeep)),
                    )
                  : null,
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.brand)),
                error: (e, _) => Center(
                  child: Text('Impossible de charger les notifications.',
                      style: AppText.ui(size: 13, color: AppColors.inkMid)),
                ),
                data: (_) {
                  if (_items.isEmpty) {
                    return Center(
                      child: Text('Aucune notification',
                          style:
                              AppText.ui(size: 14, color: AppColors.inkMid)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      _local = null;
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadCountProvider);
                      await ref.read(notificationsProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        LipaCard(
                          child: Column(
                            children: [
                              for (var i = 0; i < _items.length; i++)
                                _NotifRow(
                                  notif: _items[i],
                                  divider: i > 0,
                                  onTap: () => _open(_items[i]),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const InfoBanner(
                          text:
                              'Les notifications arrivent quelques secondes après l’événement. Tirez vers le bas pour actualiser.',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow(
      {required this.notif, required this.onTap, this.divider = false});
  final AppNotification notif;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final isBill = notif.category == NotificationCategory.billPayment;
    final unread = notif.status.isUnread;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: divider
              ? const Border(top: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isBill ? AppColors.brandSoft : AppColors.infoSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                      isBill ? Icons.receipt_long : Icons.send,
                      size: 18,
                      color: isBill ? AppColors.brandDeep : AppColors.info),
                ),
                if (unread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(notif.title,
                            style: AppText.ui(
                                size: 14,
                                weight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(fmtRelativeFr(notif.createdAt),
                          style: AppText.mono(
                              size: 11.5, color: AppColors.inkLow)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notif.body,
                      style: AppText.ui(
                          size: 13, color: AppColors.inkMid, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
