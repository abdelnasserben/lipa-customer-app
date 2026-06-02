import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_input_formatter.dart';
import '../../core/widgets/common.dart';
import '../../data/models/transaction.dart';
import '../customer/customer_providers.dart';
import 'send_amount_screen.dart';

/// Send step 1 — choose / type recipient (design: customer.jsx SendStep1).
class SendRecipientScreen extends ConsumerStatefulWidget {
  const SendRecipientScreen({super.key});

  @override
  ConsumerState<SendRecipientScreen> createState() =>
      _SendRecipientScreenState();
}

class _SendRecipientScreenState extends ConsumerState<SendRecipientScreen> {
  final _phone = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Always re-fetch on open so a recipient added by a recent transfer (or
    // updated server-side) shows up — the provider is autoDispose but can stay
    // cached while this tab's subtree lingers in the IndexedStack.
    Future.microtask(() => ref.invalidate(beneficiariesProvider));
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _continueWithTyped() {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return;
    final b = Beneficiary(
      customerId: '',
      fullName: fmtPhone('269', digits),
      phoneCountryCode: '269',
      phoneNumber: digits,
    );
    _goAmount(b);
  }

  void _goAmount(Beneficiary b) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SendAmountScreen(recipient: b)),
      );

  @override
  Widget build(BuildContext context) {
    final beneficiaries = ref.watch(beneficiariesProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ScreenHeader(title: 'Envoyer', onBack: () => Navigator.pop(context)),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(beneficiariesProvider);
                  await ref.read(beneficiariesProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                  Text('Numéro du destinataire',
                      style: AppText.ui(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: AppColors.inkLow,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderHi),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        Container(
                          width: 84,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceAlt,
                            border: Border(
                                right: BorderSide(color: AppColors.border)),
                          ),
                          child: Text('+269',
                              style: AppText.mono(
                                  size: 15, weight: FontWeight.w600)),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: const [
                                ComorianPhoneFormatter(),
                              ],
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _continueWithTyped(),
                              style: AppText.mono(size: 17, letterSpacing: 0.6),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: '300 00 00',
                                hintStyle: AppText.mono(
                                    size: 17,
                                    letterSpacing: 0.6,
                                    color: AppColors.inkFaint),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_phone.text.replaceAll(RegExp(r'\D'), '').length >= 4) ...[
                    const SizedBox(height: 14),
                    LipaButton(
                      label: 'Continuer',
                      size: BtnSize.lg,
                      full: true,
                      onPressed: _continueWithTyped,
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text('RÉCENTS',
                      style: AppText.ui(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: AppColors.inkLow,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  beneficiaries.maybeWhen(
                    data: (list) => LipaCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            _BeneRow(
                              b: list[i],
                              divider: i > 0,
                              onTap: () => _goAmount(list[i]),
                            ),
                        ],
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeneRow extends StatelessWidget {
  const _BeneRow({required this.b, required this.onTap, this.divider = false});
  final Beneficiary b;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: divider
              ? const Border(top: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceAlt,
              child: Text(b.initials,
                  style: AppText.ui(size: 14, weight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.fullName,
                      style: AppText.ui(size: 14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(fmtPhone(b.phoneCountryCode, b.phoneNumber),
                      style: AppText.mono(size: 12.5, color: AppColors.inkMid)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkLow),
          ],
        ),
      ),
    );
  }
}
