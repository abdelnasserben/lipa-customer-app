import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/bill_payment.dart';
import 'bill_detail_screen.dart';

/// Post-initiation confirmation (status QUEUED). Cites the announced delay and
/// routes to the tracking/detail screen (spec §10.5).
class BillReceiptScreen extends ConsumerWidget {
  const BillReceiptScreen({
    super.key,
    required this.provider,
    required this.service,
    required this.reference,
    required this.result,
  });

  final BillCatalogProvider provider;
  final BillService service;
  final String reference;
  final BillPaymentResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fee = result.feeAmount ?? 0;
    final amount = result.requestedAmount;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.schedule,
                    color: AppColors.brandDeep, size: 36),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('Paiement en file',
                  style: AppText.ui(size: 20, weight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                provider.announcedDelayHours != null
                    ? 'Votre paiement de ${fmtKmfNoUnit(amount)} KMF sera traité sous ${provider.announcedDelayHours}h ouvrées.'
                    : 'Votre paiement de ${fmtKmfNoUnit(amount)} KMF a été enregistré.',
                textAlign: TextAlign.center,
                style: AppText.ui(
                    size: 13.5, color: AppColors.inkMid, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LipaCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Fournisseur', value: provider.providerName),
                    DetailRow(label: 'Service', value: service.name),
                    DetailRow(label: 'Référence', value: reference, mono: true),
                    DetailRow(
                        label: 'Montant',
                        value: '${fmtKmfNoUnit(amount)} KMF',
                        mono: true),
                    DetailRow(
                        label: 'Frais',
                        value: '${fmtKmfNoUnit(fee)} KMF',
                        mono: true),
                    DetailRow(
                        label: 'Total débité',
                        value: '${fmtKmfNoUnit(amount + fee)} KMF',
                        mono: true,
                        last: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (result.billPaymentId != null)
                    LipaButton(
                      label: 'Suivre le paiement',
                      size: BtnSize.lg,
                      full: true,
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              BillDetailScreen(id: result.billPaymentId!),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  LipaButton(
                    label: 'Terminé',
                    variant: BtnVariant.secondary,
                    size: BtnSize.lg,
                    full: true,
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
