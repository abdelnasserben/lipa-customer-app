import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/transaction.dart';
import '../customer/customer_providers.dart';
import 'send_confirm_screen.dart';

/// Send step 2 — amount + note (design: customer.jsx SendStep2).
class SendAmountScreen extends ConsumerStatefulWidget {
  const SendAmountScreen({super.key, required this.recipient});
  final Beneficiary recipient;

  @override
  ConsumerState<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends ConsumerState<SendAmountScreen> {
  final _amount = TextEditingController(text: '25000');
  final _note = TextEditingController();

  int get _num => int.tryParse(_amount.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
  int get _fee => _num > 0 ? (_num * 0.01).round().clamp(50, 1 << 31) : 0;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipient;
    final balance = ref.watch(balanceProvider);
    final limits = ref.watch(limitsProvider);
    final maxTx = limits.maybeWhen(
        data: (l) => l?.maxTransactionAmount, orElse: () => null);
    final over = maxTx != null && _num > maxTx;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(title: 'Montant', onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LipaCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.surfaceAlt,
                          child: Text(r.initials,
                              style: AppText.ui(
                                  size: 14, weight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Destinataire',
                                  style: AppText.ui(
                                      size: 13, color: AppColors.inkMid)),
                              Text(r.fullName,
                                  style: AppText.ui(
                                      size: 14.5, weight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(fmtPhone(r.phoneCountryCode, r.phoneNumber),
                                  style: AppText.mono(
                                      size: 12.5, color: AppColors.inkMid)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text('Montant',
                        style: AppText.ui(size: 13, color: AppColors.inkMid)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          style: AppText.mono(
                              size: 48, weight: FontWeight.w600),
                          decoration: const InputDecoration(
                              border: InputBorder.none, isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('KMF',
                          style:
                              AppText.mono(size: 18, color: AppColors.inkMid)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style:
                            AppText.ui(size: 12.5, color: AppColors.inkMid),
                        children: [
                          const TextSpan(text: 'Frais '),
                          TextSpan(
                              text: '${fmtKmfNoUnit(_fee)} KMF',
                              style: AppText.mono(size: 12.5)),
                          const TextSpan(text: '  ·  Solde dispo '),
                          TextSpan(
                            text: balance.maybeWhen(
                                data: (b) => fmtKmfNoUnit(b.availableBalance),
                                orElse: () => '—'),
                            style: AppText.mono(size: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (over) ...[
                    const SizedBox(height: 10),
                    InfoBanner(
                      kind: PillKind.warn,
                      icon: Icons.warning_amber_rounded,
                      text:
                          'Au-delà du plafond par opération (${fmtKmfNoUnit(maxTx)} KMF).',
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      for (final a in const [5000, 10000, 25000, 50000])
                        _QuickAmount(
                          value: a,
                          onTap: () =>
                              setState(() => _amount.text = a.toString()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Note (optionnel)',
                      style: AppText.ui(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: AppColors.inkLow,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderHi),
                    ),
                    alignment: Alignment.centerLeft,
                    child: TextField(
                      controller: _note,
                      style: AppText.ui(size: 14.5),
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Pour quoi ?'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LipaButton(
                    label: 'Vérifier le transfert',
                    size: BtnSize.lg,
                    full: true,
                    onPressed: _num > 0
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SendConfirmScreen(
                                  recipient: r,
                                  amount: _num,
                                  fee: _fee,
                                  description: _note.text,
                                ),
                              ),
                            )
                        : null,
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

class _QuickAmount extends StatelessWidget {
  const _QuickAmount({required this.value, required this.onTap});
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(fmtKmfNoUnit(value),
            style: AppText.mono(size: 12, weight: FontWeight.w600)),
      ),
    );
  }
}
