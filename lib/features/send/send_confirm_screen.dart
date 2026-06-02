import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pin_sheet.dart';
import '../../data/models/transaction.dart';
import 'send_controller.dart';
import 'send_receipt_screen.dart';

/// Send step 3 — review + execute, driving the 202 control-gate loop
/// (design: customer.jsx SendStep3 / SendStepThreshold / SendStepPin).
class SendConfirmScreen extends ConsumerStatefulWidget {
  const SendConfirmScreen({
    super.key,
    required this.recipient,
    required this.amount,
    required this.fee,
    this.description,
  });

  final Beneficiary recipient;
  final int amount;
  final int fee;
  final String? description;

  @override
  ConsumerState<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends ConsumerState<SendConfirmScreen> {
  late final SendArgs _args = SendArgs(
    recipientCountryCode: widget.recipient.phoneCountryCode,
    recipientPhone: widget.recipient.phoneNumber,
    amount: widget.amount,
    description: widget.description,
  );

  bool _sheetOpen = false;

  @override
  Widget build(BuildContext context) {
    // React to phase transitions to drive the gate UI.
    ref.listen(sendControllerProvider(_args), (prev, next) {
      switch (next.phase) {
        case SendPhase.needsConfirmation:
          _showConfirmationSheet();
        case SendPhase.needsPin:
          _showPinSheet();
        case SendPhase.executed:
          if (_sheetOpen) Navigator.of(context).pop(); // close sheet
          _sheetOpen = false;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SendReceiptScreen(
                recipient: widget.recipient,
                amount: widget.amount,
                fee: widget.fee,
                result: next.result!,
              ),
            ),
          );
        case SendPhase.error:
          if (_sheetOpen) {
            // Let the PIN sheet show the error inline; rebuild handles it.
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(next.errorMessage ?? 'Erreur')),
            );
          }
        case SendPhase.idle:
        case SendPhase.submitting:
          break;
      }
    });

    final state = ref.watch(sendControllerProvider(_args));
    final ctrl = ref.read(sendControllerProvider(_args).notifier);
    final r = widget.recipient;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
                title: 'Confirmation', onBack: () => Navigator.pop(context)),
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
                        Text('Vous envoyez',
                            style: AppText.ui(
                                size: 13, color: AppColors.inkMid)),
                        const SizedBox(height: 4),
                        Text.rich(TextSpan(children: [
                          TextSpan(
                              text: fmtKmfNoUnit(widget.amount),
                              style: AppText.mono(
                                  size: 44, weight: FontWeight.w600)),
                          TextSpan(
                              text: '  KMF',
                              style: AppText.mono(
                                  size: 17, color: AppColors.inkLow)),
                        ])),
                        const SizedBox(height: 4),
                        Text.rich(TextSpan(
                          style:
                              AppText.ui(size: 13, color: AppColors.inkMid),
                          children: [
                            const TextSpan(text: 'à '),
                            TextSpan(
                                text: r.fullName,
                                style: AppText.ui(
                                    size: 13, weight: FontWeight.w600)),
                          ],
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LipaCard(
                    child: Column(
                      children: [
                        DetailRow(
                            label: 'Destinataire',
                            value: fmtPhone(
                                r.phoneCountryCode, r.phoneNumber),
                            mono: true),
                        DetailRow(
                            label: 'Montant',
                            value: '${fmtKmfNoUnit(widget.amount)} KMF',
                            mono: true),
                        DetailRow(
                            label: 'Frais',
                            value: '${fmtKmfNoUnit(widget.fee)} KMF',
                            mono: true),
                        DetailRow(
                            label: 'Reçu par le destinataire',
                            value:
                                '${fmtKmfNoUnit(widget.amount - widget.fee)} KMF',
                            mono: true),
                        DetailRow(
                            label: 'Description',
                            value: (widget.description?.isNotEmpty ?? false)
                                ? widget.description!
                                : '—',
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
                    label: 'Envoyer ${fmtKmfNoUnit(widget.amount)} KMF',
                    size: BtnSize.lg,
                    full: true,
                    loading: state.phase == SendPhase.submitting,
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
    final ctrl = ref.read(sendControllerProvider(_args).notifier);
    final threshold =
        ref.read(sendControllerProvider(_args)).matchedThreshold ?? 0;
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
                  'Ce transfert dépasse votre palier habituel de ${fmtKmfNoUnit(threshold)} KMF. Vérifiez le destinataire avant de confirmer.',
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
                    label: 'Confirmer & continuer',
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
    final ctrl = ref.read(sendControllerProvider(_args).notifier);
    _sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Consumer(builder: (context, ref, _) {
          final s = ref.watch(sendControllerProvider(_args));
          return PinSheet(
            title: 'Saisir votre PIN',
            subtitle:
                'Confirmez avec votre PIN pour envoyer ${fmtKmfNoUnit(widget.amount)} KMF à ${widget.recipient.fullName}.',
            submitting: s.phase == SendPhase.submitting,
            errorMessage:
                s.phase == SendPhase.error ? s.errorMessage : null,
            onSubmit: (pin) => ctrl.submitPin(pin),
          );
        });
      },
    ).whenComplete(() => _sheetOpen = false);
  }
}
