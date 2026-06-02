import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pin_sheet.dart';
import '../../data/models/transfer_result.dart';
import 'pay_request_controller.dart';
import 'pay_request_receipt_screen.dart';

/// Payment-request preview + settlement, driving the 202 control-gate loop
/// (spec §7.5 / §10). `totalToPay` is the figure shown as "amount due".
class PayRequestScreen extends ConsumerStatefulWidget {
  const PayRequestScreen({
    super.key,
    required this.shortCode,
    required this.lookup,
  });

  final String shortCode;
  final PaymentRequestLookup lookup;

  @override
  ConsumerState<PayRequestScreen> createState() => _PayRequestScreenState();
}

class _PayRequestScreenState extends ConsumerState<PayRequestScreen> {
  bool _sheetOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(payReqControllerProvider(widget.shortCode), (prev, next) {
      switch (next.phase) {
        case PayReqPhase.needsConfirmation:
          _showConfirmationSheet();
        case PayReqPhase.needsPin:
          _showPinSheet();
        case PayReqPhase.executed:
          if (_sheetOpen) Navigator.of(context).pop();
          _sheetOpen = false;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PayRequestReceiptScreen(
                lookup: widget.lookup,
                result: next.result!,
              ),
            ),
          );
        case PayReqPhase.error:
          if (!_sheetOpen) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(next.errorMessage ?? 'Erreur')),
            );
          }
        case PayReqPhase.idle:
        case PayReqPhase.submitting:
          break;
      }
    });

    final state = ref.watch(payReqControllerProvider(widget.shortCode));
    final ctrl = ref.read(payReqControllerProvider(widget.shortCode).notifier);
    final l = widget.lookup;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
                title: 'Demande de paiement',
                onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LipaCard(
                    radius: AppRadius.card,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Text('À payer',
                            style: AppText.ui(
                                size: 13, color: AppColors.inkMid)),
                        const SizedBox(height: 4),
                        Text.rich(TextSpan(children: [
                          TextSpan(
                              text: fmtKmfNoUnit(l.totalToPay),
                              style: AppText.mono(
                                  size: 44, weight: FontWeight.w600)),
                          TextSpan(
                              text: '  KMF',
                              style: AppText.mono(
                                  size: 17, color: AppColors.inkLow)),
                        ])),
                        const SizedBox(height: 6),
                        Text(l.beneficiaryName,
                            style: AppText.ui(
                                size: 14.5, weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LipaCard(
                    child: Column(
                      children: [
                        DetailRow(label: 'Marchand', value: l.beneficiaryName),
                        if (l.label != null && l.label!.isNotEmpty)
                          DetailRow(label: 'Objet', value: l.label!),
                        DetailRow(
                            label: 'Montant',
                            value: '${fmtKmfNoUnit(l.amount)} KMF',
                            mono: true),
                        DetailRow(
                            label: 'Frais',
                            value: '${fmtKmfNoUnit(l.feePreview)} KMF',
                            mono: true),
                        DetailRow(
                            label: 'Total à payer',
                            value: '${fmtKmfNoUnit(l.totalToPay)} KMF',
                            mono: true),
                        DetailRow(
                            label: 'Code',
                            value: widget.shortCode,
                            mono: true),
                        DetailRow(
                            label: 'Expire',
                            value: fmtDateTimeFr(l.expiresAt),
                            last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      'En confirmant, vous autorisez le débit de votre portefeuille.',
                      style: AppText.ui(
                          size: 12.5, color: AppColors.inkMid, height: 1.55)),
                  const SizedBox(height: 16),
                  LipaButton(
                    label: 'Payer ${fmtKmfNoUnit(l.totalToPay)} KMF',
                    size: BtnSize.lg,
                    full: true,
                    loading: state.phase == PayReqPhase.submitting,
                    onPressed: () => ctrl.submit(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationSheet() {
    final ctrl =
        ref.read(payReqControllerProvider(widget.shortCode).notifier);
    final threshold =
        ref.read(payReqControllerProvider(widget.shortCode)).matchedThreshold ??
            0;
    _sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: const Color(0xFFD6D2C5),
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text('Montant inhabituel',
                style: AppText.ui(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            InfoBanner(
              kind: PillKind.warn,
              icon: Icons.warning_amber_rounded,
              text:
                  'Ce paiement dépasse votre palier habituel de ${fmtKmfNoUnit(threshold)} KMF. Vérifiez le marchand avant de confirmer.',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: LipaButton(
                    label: 'Retour',
                    variant: BtnVariant.secondary,
                    onPressed: () {
                      _sheetOpen = false;
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LipaButton(
                    label: 'Confirmer',
                    onPressed: () {
                      Navigator.pop(context);
                      _sheetOpen = false;
                      ctrl.acknowledgeConfirmation();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() => _sheetOpen = false);
  }

  void _showPinSheet() {
    final ctrl =
        ref.read(payReqControllerProvider(widget.shortCode).notifier);
    _sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Consumer(builder: (context, ref, _) {
          final s = ref.watch(payReqControllerProvider(widget.shortCode));
          return PinSheet(
            title: 'Saisir votre PIN',
            subtitle:
                'Confirmez avec votre PIN pour payer ${fmtKmfNoUnit(widget.lookup.totalToPay)} KMF à ${widget.lookup.beneficiaryName}.',
            submitting: s.phase == PayReqPhase.submitting,
            errorMessage:
                s.phase == PayReqPhase.error ? s.errorMessage : null,
            onSubmit: (pin) => ctrl.submitPin(pin),
          );
        });
      },
    ).whenComplete(() => _sheetOpen = false);
  }
}
