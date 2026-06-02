import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/pin_sheet.dart';
import '../../data/models/bill_payment.dart';
import '../customer/customer_providers.dart';
import 'bill_pay_controller.dart';
import 'bill_receipt_screen.dart';

/// Bill-pay step: enter reference + amount, then run the 202 control-gate
/// loop (spec §10.5). On success, routes to the in-app receipt/confirmation.
class BillInitiateScreen extends ConsumerStatefulWidget {
  const BillInitiateScreen({
    super.key,
    required this.provider,
    required this.service,
  });

  final BillCatalogProvider provider;
  final BillService service;

  @override
  ConsumerState<BillInitiateScreen> createState() =>
      _BillInitiateScreenState();
}

class _BillInitiateScreenState extends ConsumerState<BillInitiateScreen> {
  final _reference = TextEditingController();
  final _amount = TextEditingController();
  bool _sheetOpen = false;
  BillPayArgs? _args;

  int get _num => int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
  String get _ref => _reference.text.trim();

  @override
  void dispose() {
    _reference.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? get _referenceError {
    if (_ref.isEmpty) return null;
    if (!widget.provider.referenceLooksValid(_ref)) {
      final ex = widget.provider.referenceExample;
      return ex != null && ex.isNotEmpty
          ? 'Format invalide. Exemple : $ex'
          : 'Format de référence invalide.';
    }
    return null;
  }

  String? get _amountError {
    final min = widget.service.minAmount;
    final max = widget.service.maxAmount;
    if (_num == 0) return null;
    if (min != null && _num < min) {
      return 'Minimum ${fmtKmfNoUnit(min)} KMF.';
    }
    if (max != null && _num > max) {
      return 'Maximum ${fmtKmfNoUnit(max)} KMF.';
    }
    return null;
  }

  bool get _canSubmit =>
      _ref.isNotEmpty &&
      _num > 0 &&
      _referenceError == null &&
      _amountError == null;

  void _start() {
    setState(() {
      _args = BillPayArgs(
        serviceId: widget.service.serviceId,
        reference: _ref,
        amount: _num,
      );
    });
    // Submit only after the rebuild has registered the `ref.listen` below, so
    // the first phase transition (needsPin / needsConfirmation) is never
    // dropped — otherwise tapping "Payer" appears to do nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _args == null) return;
      ref.read(billPayControllerProvider(_args!).notifier).submit();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_args != null) {
      ref.listen(billPayControllerProvider(_args!), (prev, next) {
        switch (next.phase) {
          case BillPayPhase.needsConfirmation:
            _showConfirmationSheet();
          case BillPayPhase.needsPin:
            _showPinSheet();
          case BillPayPhase.executed:
            if (_sheetOpen) Navigator.of(context).pop();
            _sheetOpen = false;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => BillReceiptScreen(
                  provider: widget.provider,
                  service: widget.service,
                  reference: _ref,
                  result: next.result!,
                ),
              ),
            );
          case BillPayPhase.error:
            if (!_sheetOpen) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(next.errorMessage ?? 'Erreur')),
              );
            }
          case BillPayPhase.idle:
          case BillPayPhase.submitting:
            break;
        }
      });
    }

    final submitting = _args != null &&
        ref.watch(billPayControllerProvider(_args!)).phase ==
            BillPayPhase.submitting;
    final balance = ref.watch(balanceProvider);
    final p = widget.provider;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
                title: widget.service.name,
                onBack: () => Navigator.pop(context),
                subtitle: p.providerName),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('RÉFÉRENCE',
                      style: AppText.ui(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: AppColors.inkLow,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _reference,
                    hint: p.referenceExample ?? 'N° de compteur / abonné',
                    keyboardType: TextInputType.text,
                    onChanged: () => setState(() {}),
                  ),
                  if (_referenceError != null) ...[
                    const SizedBox(height: 6),
                    Text(_referenceError!,
                        style:
                            AppText.ui(size: 12, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 20),
                  Text('MONTANT',
                      style: AppText.ui(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: AppColors.inkLow,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  _Field(
                    controller: _amount,
                    hint: '0',
                    suffix: 'KMF',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    mono: true,
                    onChanged: () => setState(() {}),
                  ),
                  if (_amountError != null) ...[
                    const SizedBox(height: 6),
                    Text(_amountError!,
                        style:
                            AppText.ui(size: 12, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Solde disponible ${balance.maybeWhen(data: (b) => fmtKmfNoUnit(b.availableBalance), orElse: () => '—')} KMF',
                    style: AppText.ui(size: 12.5, color: AppColors.inkMid),
                  ),
                  const SizedBox(height: 18),
                  if (p.announcedDelayHours != null)
                    InfoBanner(
                      icon: Icons.schedule,
                      text:
                          'Paiement traité sous ${p.announcedDelayHours}h ouvrées '
                          '(${_window(p)}). Le montant est débité puis mis en file.',
                    ),
                  const SizedBox(height: 18),
                  LipaButton(
                    label: 'Payer',
                    size: BtnSize.lg,
                    full: true,
                    loading: submitting,
                    onPressed: _canSubmit ? _start : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _window(BillCatalogProvider p) {
    final start = p.processingHoursStart ?? '08:00';
    final end = p.processingHoursEnd ?? '18:00';
    final days = switch (p.processingDays) {
      'MON-SAT' => 'lun–sam',
      'MON-FRI' => 'lun–ven',
      _ => p.processingDays ?? 'lun–sam',
    };
    return '$start–$end, $days';
  }

  void _showConfirmationSheet() {
    final ctrl = ref.read(billPayControllerProvider(_args!).notifier);
    final threshold =
        ref.read(billPayControllerProvider(_args!)).matchedThreshold ?? 0;
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
                  'Ce paiement dépasse votre palier habituel de ${fmtKmfNoUnit(threshold)} KMF. Vérifiez la référence avant de confirmer.',
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
    final ctrl = ref.read(billPayControllerProvider(_args!).notifier);
    _sheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Consumer(builder: (context, ref, _) {
          final s = ref.watch(billPayControllerProvider(_args!));
          return PinSheet(
            title: 'Saisir votre PIN',
            subtitle:
                'Confirmez avec votre PIN pour payer ${fmtKmfNoUnit(_num)} KMF à ${widget.provider.providerName}.',
            submitting: s.phase == BillPayPhase.submitting,
            errorMessage:
                s.phase == BillPayPhase.error ? s.errorMessage : null,
            onSubmit: (pin) => ctrl.submitPin(pin),
          );
        });
      },
    ).whenComplete(() => _sheetOpen = false);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
    this.mono = false,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffix;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderHi),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: (_) => onChanged(),
              style: mono
                  ? AppText.mono(size: 18, weight: FontWeight.w600)
                  : AppText.ui(size: 15.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: mono
                    ? AppText.mono(
                        size: 18,
                        weight: FontWeight.w600,
                        color: AppColors.inkFaint)
                    : AppText.ui(size: 15.5, color: AppColors.inkFaint),
              ),
            ),
          ),
          if (suffix != null)
            Text(suffix!, style: AppText.mono(size: 14, color: AppColors.inkMid)),
        ],
      ),
    );
  }
}
