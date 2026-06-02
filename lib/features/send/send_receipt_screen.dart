import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/transaction_receipt.dart';
import '../../core/widgets/common.dart';
import '../../data/models/transaction.dart';
import '../../data/models/transfer_result.dart';

/// P2P success receipt (design: customer.jsx SendStepReceipt).
class SendReceiptScreen extends StatelessWidget {
  const SendReceiptScreen({
    super.key,
    required this.recipient,
    required this.amount,
    required this.fee,
    required this.result,
  });

  final Beneficiary recipient;
  final int amount;
  final int fee;
  final P2pTransferResult result;

  @override
  Widget build(BuildContext context) {
    final feeShown = result.feeAmount ?? fee;
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
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 20),
                  Text(result.replayed == true ? 'Déjà envoyé' : 'Envoyé',
                      style: AppText.ui(
                          size: 24,
                          weight: FontWeight.w700,
                          letterSpacing: -0.48)),
                  const SizedBox(height: 4),
                  Text('${recipient.fullName} reçoit les fonds instantanément.',
                      textAlign: TextAlign.center,
                      style: AppText.ui(size: 14, color: AppColors.inkMid)),
                  const SizedBox(height: 18),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: fmtKmfNoUnit(amount),
                        style: AppText.mono(
                            size: 42, weight: FontWeight.w600)),
                    TextSpan(
                        text: '  KMF',
                        style: AppText.mono(
                            size: 16, color: AppColors.inkLow)),
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
                            label: 'Destinataire',
                            value: fmtPhone(recipient.phoneCountryCode,
                                recipient.phoneNumber),
                            mono: true),
                        DetailRow(
                            label: 'Frais',
                            value: '${fmtKmfNoUnit(feeShown)} KMF',
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
                  Row(
                    children: [
                      Expanded(
                        child: LipaButton(
                          label: 'Reçu PDF',
                          variant: BtnVariant.secondary,
                          icon: const Icon(Icons.download),
                          onPressed: () => _openReceiptPdf(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LipaButton(
                          label: 'Terminé',
                          onPressed: () => Navigator.of(context)
                              .popUntil((r) => r.isFirst),
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

  /// Builds a transaction from the transfer result and opens the system
  /// print/preview sheet for the receipt PDF (save/share from there).
  Future<void> _openReceiptPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final tx = receiptFromP2p(
      result: result,
      recipient: recipient,
      amount: amount,
      fee: fee,
    );
    try {
      await Printing.layoutPdf(
        onLayout: (_) => receiptPdfBytes(tx),
        name: 'recu-lipa-${tx.id}.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de générer le reçu PDF.')),
      );
    }
  }
}
