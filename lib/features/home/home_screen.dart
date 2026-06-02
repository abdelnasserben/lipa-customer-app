import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/lipa_brand.dart';
import '../../data/models/customer_profile.dart' show CustomerBalance;
import '../../data/models/transaction.dart';
import '../activity/statement_screen.dart';
import '../activity/transaction_detail_screen.dart';
import '../activity/tx_row.dart';
import '../customer/customer_providers.dart';
import '../notifications/notifications_screen.dart';
import '../pay/pay_request_code_screen.dart';
import '../send/send_recipient_screen.dart';
import '../send/send_amount_screen.dart';

/// Customer home / dashboard (design: customer.jsx CustomerHome).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final balance = ref.watch(balanceProvider);
    final activity = ref.watch(activityProvider);
    final beneficiaries = ref.watch(beneficiariesProvider);
    final unread = ref.watch(unreadCountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(balanceProvider);
        ref.invalidate(activityProvider);
        ref.invalidate(unreadCountProvider);
        await ref.read(activityProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Greeting + bell.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bonjour',
                        style:
                            AppText.ui(size: 13, color: AppColors.inkMid)),
                    const SizedBox(height: 2),
                    Text(
                      profile.maybeWhen(
                        data: (p) => p.fullName,
                        orElse: () => '…',
                      ),
                      style: AppText.ui(
                          size: 19,
                          weight: FontWeight.w700,
                          letterSpacing: -0.28),
                    ),
                  ],
                ),
                CircleButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                  badge: unread.maybeWhen(
                    data: (n) => n > 0 ? CountBadge(count: n) : null,
                    orElse: () => null,
                  ),
                  child: const Icon(Icons.notifications_none),
                ),
              ],
            ),
          ),

          // Balance hero card.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _BalanceCard(
              balance: balance,
              onSend: () => _pushSendRecipient(context),
              onScan: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PayRequestCodeScreen()),
              ),
              onStatement: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatementScreen()),
              ),
            ),
          ),

          // Beneficiaries.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
            child: Text('Envoyer à nouveau',
                style: AppText.ui(size: 15, weight: FontWeight.w700)),
          ),
          SizedBox(
            height: 92,
            child: beneficiaries.maybeWhen(
              data: (list) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
                children: [
                  for (final b in list)
                    _Avatar(
                      initials: b.initials,
                      label: b.firstName,
                      onTap: () => _pushSendAmount(context, b),
                    ),
                  _Avatar(
                    initials: '+',
                    label: 'Nouveau',
                    dashed: true,
                    onTap: () => _pushSendRecipient(context),
                  ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),

          // Recent activity.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Activité récente',
                    style: AppText.ui(size: 15, weight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: activity.when(
              loading: () => const _ActivitySkeleton(),
              error: (e, _) => LipaCard(
                padding: const EdgeInsets.all(20),
                child: Text('Impossible de charger l’activité.',
                    style: AppText.ui(size: 13, color: AppColors.inkMid)),
              ),
              data: (txs) => LipaCard(
                child: Column(
                  children: [
                    for (var i = 0; i < txs.take(5).length; i++)
                      TxRow(
                        tx: txs[i],
                        divider: i > 0,
                        onTap: () => _pushTxDetail(context, txs[i]),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pushSendRecipient(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SendRecipientScreen()),
      );

  void _pushSendAmount(BuildContext context, b) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SendAmountScreen(recipient: b)),
      );

  void _pushTxDetail(BuildContext context, CustomerTransaction tx) =>
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: tx)),
      );
}

class _BalanceCard extends StatefulWidget {
  const _BalanceCard({
    required this.balance,
    required this.onSend,
    required this.onScan,
    required this.onStatement,
  });
  final AsyncValue<CustomerBalance> balance;
  final VoidCallback onSend;
  final VoidCallback onScan;
  final VoidCallback onStatement;

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.hero),
      child: Stack(
        children: [
          Container(
            color: AppColors.nearBlack,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SOLDE PORTEFEUILLE',
                        style: AppText.ui(
                            size: 12.5,
                            weight: FontWeight.w600,
                            color: Colors.white54,
                            letterSpacing: 1)),
                    InkWell(
                      onTap: () => setState(() => _hidden = !_hidden),
                      child: Icon(
                          _hidden ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                          color: Colors.white60),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                widget.balance.when(
                  loading: () => Text('••• •••',
                      style: AppText.mono(
                          size: 38,
                          weight: FontWeight.w600,
                          color: Colors.white)),
                  error: (_, _) => Text('—',
                      style: AppText.mono(
                          size: 38, color: Colors.white)),
                  data: (b) => Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _hidden ? '••• •••' : fmtKmfNoUnit(b.availableBalance),
                        style: AppText.mono(
                            size: 38,
                            weight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text('KMF',
                          style: AppText.mono(
                              size: 14, color: Colors.white54)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                widget.balance.maybeWhen(
                  data: (b) => Text.rich(
                    TextSpan(
                      style: AppText.ui(size: 12.5, color: Colors.white54),
                      children: [
                        TextSpan(
                            text:
                                '${fmtKmfNoUnit(b.frozenBalance)} KMF gelés · Portefeuille '),
                        // Wallet status dot in green, matching the design (#8fd1a8).
                        const TextSpan(
                          text: '● Actif',
                          style: TextStyle(color: Color(0xFF8FD1A8)),
                        ),
                      ],
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: 22),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _QuickAction(
                        icon: Icons.send,
                        label: 'Envoyer',
                        onTap: widget.onSend),
                    const SizedBox(width: 8),
                    _QuickAction(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scanner',
                        onTap: widget.onScan),
                    const SizedBox(width: 8),
                    _QuickAction(
                        icon: Icons.description_outlined,
                        label: 'Relevé',
                        onTap: widget.onStatement),
                  ],
                ),
              ],
            ),
          ),
          const GridBackground(),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: Colors.white),
              const SizedBox(height: 6),
              Text(label,
                  style: AppText.ui(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.label,
    required this.onTap,
    this.dashed = false,
  });
  final String initials;
  final String label;
  final VoidCallback onTap;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dashed ? AppColors.surfaceAlt : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          dashed ? AppColors.borderHi : AppColors.border),
                ),
                child: dashed
                    ? const Icon(Icons.add, color: AppColors.inkMid)
                    : Text(initials,
                        style: AppText.ui(
                            size: 16, weight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(
                      size: 11.5,
                      color: dashed ? AppColors.inkMid : AppColors.inkHi)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();
  @override
  Widget build(BuildContext context) {
    return LipaCard(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.brand),
        ),
      ),
    );
  }
}
