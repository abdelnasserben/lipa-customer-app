import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../bills/bill_catalogue_screen.dart';
import '../bills/bill_history_screen.dart';
import '../customer/customer_providers.dart';
import '../send/send_amount_screen.dart';
import '../send/send_recipient_screen.dart';
import 'pay_request_code_screen.dart';

/// The Pay hub opened by the central FAB (design: customer-extras.jsx PayHub).
/// Lists the payment entry points and recent beneficiaries.
///
/// Note: "Payer une facture" (bill-pay) is feature-flagged on the backend
/// (404 → hidden); it lands in phase 2 alongside the bill catalogue.
class PayHubScreen extends ConsumerWidget {
  const PayHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beneficiaries = ref.watch(beneficiariesProvider);
    final billPayOn = ref.watch(billPayEnabledProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          children: [
            const ScreenHeader(title: 'Payer'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LipaCard(
                radius: AppRadius.xxl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _PayRow(
                      icon: Icons.send,
                      accent: _Accent.brand,
                      title: 'Envoyer à un contact',
                      sub: 'Transfert immédiat par numéro de téléphone',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SendRecipientScreen()),
                      ),
                    ),
                    _PayRow(
                      icon: Icons.qr_code_scanner,
                      accent: _Accent.info,
                      title: 'Payer un marchand',
                      sub: 'Saisir un code de demande de paiement',
                      divider: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PayRequestCodeScreen()),
                      ),
                    ),
                    // Bill payment is feature-flagged (spec §10.5): the catalogue
                    // probe (billPayEnabledProvider) hides these when off (404).
                    if (billPayOn) ...[
                      _PayRow(
                        icon: Icons.receipt_long,
                        accent: _Accent.warn,
                        title: 'Payer une facture',
                        sub: 'Électricité, eau, télécom…',
                        divider: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const BillCatalogueScreen()),
                        ),
                      ),
                      _PayRow(
                        icon: Icons.history,
                        accent: _Accent.info,
                        title: 'Mes factures',
                        sub: 'Suivi, annulation, reçus',
                        divider: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const BillHistoryScreen()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Text('ENVOYER À NOUVEAU',
                  style: AppText.ui(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.inkLow,
                      letterSpacing: 1)),
            ),
            SizedBox(
              height: 92,
              child: beneficiaries.maybeWhen(
                data: (list) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  children: [
                    for (final b in list)
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    SendAmountScreen(recipient: b)),
                          ),
                          child: SizedBox(
                            width: 64,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: AppColors.surface,
                                  child: Text(b.initials,
                                      style: AppText.ui(
                                          size: 16,
                                          weight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 8),
                                Text(b.firstName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.ui(size: 11.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Accent { brand, info, warn }

class _PayRow extends StatelessWidget {
  const _PayRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    required this.accent,
    this.divider = false,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final _Accent accent;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (accent) {
      _Accent.brand => (AppColors.brandSoft, AppColors.brandDeep),
      _Accent.info => (AppColors.infoSoft, AppColors.info),
      _Accent.warn => (AppColors.warnSoft, AppColors.warn),
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          border: divider
              ? const Border(top: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.ui(size: 15, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: AppText.ui(
                          size: 12.5, color: AppColors.inkMid, height: 1.4)),
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
