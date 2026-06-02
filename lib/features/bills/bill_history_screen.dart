import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/bill_payment.dart';
import '../customer/customer_providers.dart';
import 'bill_detail_screen.dart';

/// Bill-payment history, newest first (spec §10.5). Tap a row → detail.
class BillHistoryScreen extends ConsumerWidget {
  const BillHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(billPaymentsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ScreenHeader(
                title: 'Mes factures', onBack: () => Navigator.pop(context)),
            Expanded(
              child: payments.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: InfoBanner(
                    kind: PillKind.warn,
                    text: 'Impossible de charger vos factures.',
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: InfoBanner(
                        text: 'Aucun paiement de facture pour le moment.',
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async =>
                        ref.invalidate(billPaymentsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _BillRow(bp: list[i]),
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

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bp});
  final CustomerBillPayment bp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LipaCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BillDetailScreen(id: bp.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.inkMid, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bp.providerName,
                          style:
                              AppText.ui(size: 14.5, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${bp.reference} · ${fmtRelativeFr(bp.createdAt)}',
                          style: AppText.ui(
                              size: 12.5, color: AppColors.inkMid)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmtKmfNoUnit(bp.amount)} KMF',
                        style:
                            AppText.mono(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    BillStatusPill(status: bp.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
