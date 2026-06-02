import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/transfer_result.dart';

/// Payment-request settlement receipt (spec §7.5). Mirrors the P2P receipt
/// but for the payer→merchant settlement.
class PayRequestReceiptScreen extends StatelessWidget {
  const PayRequestReceiptScreen({
    super.key,
    required this.lookup,
    required this.result,
  });

  final PaymentRequestLookup lookup;
  final PayPaymentRequestResult result;

  @override
  Widget build(BuildContext context) {
    final amount = result.requestedAmount ?? lookup.amount;
    final fee = result.feeAmount ?? lookup.feePreview;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Color(0x52366851),
                            blurRadius: 20,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(result.replayed ? 'Déjà payé' : 'Paiement effectué',
                      style: AppText.ui(
                          size: 24,
                          weight: FontWeight.w700,
                          letterSpacing: -0.48)),
                  const SizedBox(height: 4),
                  Text('${lookup.beneficiaryName} a reçu votre paiement.',
                      textAlign: TextAlign.center,
                      style: AppText.ui(size: 14, color: AppColors.inkMid)),
                  const SizedBox(height: 18),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: fmtKmfNoUnit(amount),
                        style:
                            AppText.mono(size: 42, weight: FontWeight.w600)),
                    TextSpan(
                        text: '  KMF',
                        style:
                            AppText.mono(size: 16, color: AppColors.inkLow)),
                  ])),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LipaCard(
                    child: Column(
                      children: [
                        DetailRow(
                            label: 'Marchand', value: lookup.beneficiaryName),
                        DetailRow(
                            label: 'Frais',
                            value: '${fmtKmfNoUnit(fee)} KMF',
                            mono: true),
                        DetailRow(
                            label: 'Date',
                            value: fmtDateTimeFr(
                                result.completedAt ?? DateTime.now())),
                        DetailRow(
                            label: 'Référence',
                            value: result.transactionId ?? '—',
                            mono: true,
                            copy: true,
                            last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LipaButton(
                    label: 'Terminé',
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
