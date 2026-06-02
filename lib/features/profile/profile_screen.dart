import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../activity/statement_screen.dart';
import '../auth/session_controller.dart';
import '../customer/customer_providers.dart';
import '../notifications/notifications_screen.dart';
import '../security/security_screen.dart';
import 'limits_screen.dart';

/// Profile tab (design: customer-extras.jsx CustomerProfile).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final balance = ref.watch(balanceProvider);
    final limits = ref.watch(limitsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const ScreenHeader(title: 'Profil'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LipaCard(
                    radius: AppRadius.xxl,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.brand,
                          child: Text(
                            profile.maybeWhen(
                                data: (p) => p.initials, orElse: () => '··'),
                            style: AppText.ui(
                                size: 20,
                                weight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: profile.maybeWhen(
                            data: (p) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.fullName,
                                    style: AppText.ui(
                                        size: 17, weight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                    fmtPhone(
                                        p.phoneCountryCode, p.phoneNumber),
                                    style: AppText.mono(
                                        size: 13, color: AppColors.inkMid)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (p.status.isActive)
                                      const StatusPill(
                                          label: '● Actif',
                                          kind: PillKind.success),
                                    const SizedBox(width: 6),
                                    if (p.isKycVerified)
                                      const StatusPill(
                                          label: 'KYC vérifié',
                                          kind: PillKind.info),
                                  ],
                                ),
                              ],
                            ),
                            orElse: () => const SizedBox(height: 56),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel('Portefeuille'),
                  const SizedBox(height: 8),
                  LipaCard(
                    child: balance.maybeWhen(
                      data: (b) => Column(
                        children: [
                          DetailRow(
                              label: 'ID portefeuille',
                              value: shortId(b.walletId),
                              mono: true,
                              copy: true),
                          DetailRow(
                              label: 'Solde disponible',
                              value: '${fmtKmfNoUnit(b.availableBalance)} KMF',
                              mono: true),
                          DetailRow(
                              label: 'Solde gelé',
                              value: '${fmtKmfNoUnit(b.frozenBalance)} KMF',
                              mono: true,
                              last: true),
                        ],
                      ),
                      orElse: () => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.brand)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel('Compte'),
                  const SizedBox(height: 8),
                  LipaCard(
                    child: Column(
                      children: [
                        _RowLink(
                          icon: Icons.shield_outlined,
                          label: 'Sécurité & PIN',
                          sub: 'PIN, TOTP',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SecurityScreen()),
                          ),
                        ),
                        _RowLink(
                          icon: Icons.receipt_long_outlined,
                          label: 'Relevé de compte',
                          sub: 'Écritures et solde courant',
                          divider: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const StatementScreen()),
                          ),
                        ),
                        _RowLink(
                          icon: Icons.list_alt,
                          label: 'Plafonds',
                          sub: limits.maybeWhen(
                              data: (l) => l?.profileName ?? 'Non configurés',
                              orElse: () => '…'),
                          divider: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LimitsScreen()),
                          ),
                        ),
                        _RowLink(
                          icon: Icons.notifications_none,
                          label: 'Notifications',
                          sub: unread.maybeWhen(
                              data: (n) => n > 0
                                  ? '$n non lue${n > 1 ? 's' : ''}'
                                  : 'Toutes lues',
                              orElse: () => '…'),
                          divider: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const NotificationsScreen()),
                          ),
                        ),
                        _RowLink(
                          icon: Icons.person_outline,
                          label: 'Données personnelles',
                          sub: 'Adresse, KYC',
                          divider: true,
                          onTap: () => _comingSoon(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => _confirmLogout(context, ref),
                    child: Text('Se déconnecter',
                        style: AppText.ui(
                            size: 14.5,
                            weight: FontWeight.w600,
                            color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bientôt disponible.')),
      );

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Se déconnecter ?',
            style: AppText.ui(size: 17, weight: FontWeight.w700)),
        content: Text('Vous devrez vous reconnecter avec votre PIN.',
            style: AppText.ui(size: 14, color: AppColors.inkMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Annuler',
                style: AppText.ui(size: 14, color: AppColors.inkMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Se déconnecter',
                style: AppText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(text.toUpperCase(),
            style: AppText.ui(
                size: 11.5,
                weight: FontWeight.w600,
                color: AppColors.inkLow,
                letterSpacing: 1)),
      );
}

class _RowLink extends StatelessWidget {
  const _RowLink({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.divider = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: divider
              ? const Border(top: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: AppColors.inkHi),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppText.ui(size: 14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style:
                          AppText.ui(size: 12.5, color: AppColors.inkMid)),
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
