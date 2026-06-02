import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/transaction_receipt.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/transaction.dart';

/// Transaction detail (design: customer.jsx TxDetail).
///
/// Re-fetches the full transaction by id so the detail reflects the
/// authoritative server state, falling back to the row we were given.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.tx});
  final CustomerTransaction tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_txDetailProvider(tx.id));
    final t = detail.maybeWhen(data: (d) => d, orElse: () => tx);
    final positive = t.isIncoming;
    final declined = t.status.isDeclined;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
                title: 'Transaction', onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LipaCard(
                    radius: AppRadius.card,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      // Stretch so the card fills the full width like the
                      // detail card below; children stay visually centered.
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: positive
                                  ? AppColors.brandSoft
                                  : declined
                                      ? AppColors.dangerSoft
                                      : const Color(0xFFF1EFE8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              declined
                                  ? Icons.close
                                  : positive
                                      ? Icons.south_west
                                      : Icons.north_east,
                              color: positive
                                  ? AppColors.brandDeep
                                  : declined
                                      ? AppColors.danger
                                      : AppColors.inkHi,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(positive ? 'Reçu de' : 'Envoyé à',
                            textAlign: TextAlign.center,
                            style: AppText.ui(
                                size: 13, color: AppColors.inkMid)),
                        const SizedBox(height: 2),
                        Text(t.counterparty ?? typeLabelFr(t.type),
                            textAlign: TextAlign.center,
                            style: AppText.ui(
                                size: 18, weight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        Text.rich(
                          textAlign: TextAlign.center,
                          TextSpan(children: [
                            TextSpan(
                              text:
                                  '${positive ? '+' : '−'}${fmtKmfNoUnit(t.requestedAmount)}',
                              style: AppText.mono(
                                size: 36,
                                weight: FontWeight.w600,
                                color: declined
                                    ? AppColors.inkLow
                                    : AppColors.inkHi,
                              ).copyWith(
                                decoration: declined
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            TextSpan(
                                text: '  KMF',
                                style: AppText.mono(
                                    size: 16, color: AppColors.inkLow)),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        Center(child: TxStatusPill(status: t.status)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LipaCard(
                    child: Column(
                      children: [
                        DetailRow(label: 'Date', value: fmtDateTimeFr(t.createdAt)),
                        DetailRow(label: 'Type', value: typeLabelFr(t.type)),
                        DetailRow(
                            label: 'Référence', value: t.id, mono: true, copy: true),
                        if (t.feeAmount > 0)
                          DetailRow(
                              label: 'Frais',
                              value: '${fmtKmfNoUnit(t.feeAmount)} KMF',
                              mono: true),
                        DetailRow(
                            label: 'Montant net',
                            value: '${fmtKmfNoUnit(t.netAmountToDestination)} KMF',
                            mono: true,
                            last: true),
                      ],
                    ),
                  ),
                  if (declined) ...[
                    const SizedBox(height: 14),
                    InfoBanner(
                      kind: PillKind.declined,
                      icon: Icons.warning_amber_rounded,
                      text: _declineMsg(t.declineReason),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LipaButton(
                          label: 'Reçu PDF',
                          variant: BtnVariant.secondary,
                          icon: const Icon(Icons.download),
                          onPressed: () => _openReceiptPdf(context, t),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LipaButton(
                          label: 'Partager',
                          variant: BtnVariant.secondary,
                          icon: const Icon(Icons.share),
                          onPressed: () => _shareReceipt(context, t),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generates the receipt PDF locally and opens the system print/preview
  /// sheet, from which the user can save or share the file.
  Future<void> _openReceiptPdf(
      BuildContext context, CustomerTransaction t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
        onLayout: (_) => receiptPdfBytes(t),
        name: 'recu-lipa-${t.id}.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de générer le reçu PDF.')),
      );
    }
  }

  /// Opens the native share sheet with a plain-text recap of the transaction.
  Future<void> _shareReceipt(
      BuildContext context, CustomerTransaction t) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      receiptShareText(t),
      subject: 'Reçu Lipa',
      sharePositionOrigin:
          box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  String _declineMsg(String? reason) => switch (reason) {
        'INSUFFICIENT_BALANCE' =>
          'Solde insuffisant. Rechargez votre portefeuille auprès d’un agent Lipa.',
        'LIMIT_EXCEEDED' =>
          'Plafond dépassé. Consultez vos plafonds dans Profil → Plafonds.',
        'WALLET_FROZEN' => 'Portefeuille gelé. Contactez le support Lipa.',
        _ => 'Transaction refusée.',
      };
}

/// Detail re-fetch keyed by id. Falls through to the passed row on error.
final _txDetailProvider =
    FutureProvider.autoDispose.family<CustomerTransaction, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getTransaction(id);
});
