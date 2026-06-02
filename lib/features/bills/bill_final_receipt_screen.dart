import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/lipa_brand.dart';
import '../../data/models/bill_payment.dart';

/// The Lipa receipt for a SUCCEEDED bill payment. The backend returns JSON
/// (spec §7.4a) and the app renders the visual document.
class BillFinalReceiptScreen extends ConsumerWidget {
  const BillFinalReceiptScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(_receiptProvider(id));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ScreenHeader(title: 'Reçu', onBack: () => Navigator.pop(context)),
            Expanded(
              child: receipt.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: InfoBanner(
                    kind: PillKind.warn,
                    text: 'Reçu indisponible pour le moment.',
                  ),
                ),
                data: (r) => _Receipt(receipt: r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.receipt});
  final BillPaymentReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        LipaCard(
          radius: AppRadius.card,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: LipaWordmark(size: 26)),
              const SizedBox(height: 4),
              Center(
                child: Text('Reçu de paiement',
                    style: AppText.ui(size: 13, color: AppColors.inkMid)),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.brandSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      color: AppColors.brandDeep, size: 32),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: fmtKmfNoUnit(receipt.amount),
                      style: AppText.mono(size: 34, weight: FontWeight.w600)),
                  TextSpan(
                      text: '  KMF',
                      style:
                          AppText.mono(size: 15, color: AppColors.inkLow)),
                ])),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(receipt.providerName,
                    style: AppText.ui(size: 14, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),
              DetailRow(label: 'Référence', value: receipt.reference, mono: true),
              if (receipt.externalReference != null)
                DetailRow(
                    label: 'N° fournisseur',
                    value: receipt.externalReference!,
                    mono: true,
                    copy: true),
              DetailRow(
                  label: 'Montant',
                  value: '${fmtKmfNoUnit(receipt.amount)} KMF',
                  mono: true),
              DetailRow(
                  label: 'Frais',
                  value: '${fmtKmfNoUnit(receipt.feeAmount)} KMF',
                  mono: true),
              DetailRow(
                  label: 'Net',
                  value: '${fmtKmfNoUnit(receipt.netAmount)} KMF',
                  mono: true),
              if (receipt.operatorCode != null)
                DetailRow(label: 'Opérateur', value: receipt.operatorCode!),
              DetailRow(
                  label: 'Payée le',
                  value: fmtDateTimeFr(receipt.completedAt),
                  last: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text('Émis par Lipa · ${receipt.paymentId}',
              style: AppText.ui(size: 11, color: AppColors.inkLow)),
        ),
      ],
    );
  }
}

final _receiptProvider =
    FutureProvider.autoDispose.family<BillPaymentReceipt, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getBillPaymentReceipt(id);
});
