import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import 'change_pin_screen.dart';
import 'security_controller.dart';
import 'totp_enroll_screen.dart';
import 'totp_revoke_screen.dart';

/// Security & PIN hub (spec §3.3): change PIN, enroll/revoke TOTP.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totpOn = ref.watch(totpEnrolledProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
                title: 'Sécurité & PIN', onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel('Code PIN'),
                  const SizedBox(height: 8),
                  LipaCard(
                    child: _Row(
                      icon: Icons.lock_outline,
                      label: 'Changer le PIN',
                      sub: 'Mettez à jour votre PIN à 4–8 chiffres',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ChangePinScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel('Double authentification (TOTP)'),
                  const SizedBox(height: 8),
                  LipaCard(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  totpOn
                                      ? 'TOTP est activé. Un code à 6 chiffres est demandé à la connexion.'
                                      : 'Ajoutez une couche de sécurité avec une application d’authentification (Google Authenticator, etc.).',
                                  style: AppText.ui(
                                      size: 13,
                                      color: AppColors.inkMid,
                                      height: 1.5),
                                ),
                              ),
                              const SizedBox(width: 10),
                              StatusPill(
                                label: totpOn ? 'Activé' : 'Inactif',
                                kind:
                                    totpOn ? PillKind.success : PillKind.neutral,
                              ),
                            ],
                          ),
                        ),
                        _Row(
                          icon: totpOn ? Icons.no_encryption_outlined : Icons.qr_code_2,
                          label: totpOn
                              ? 'Désactiver le TOTP'
                              : 'Activer le TOTP',
                          sub: totpOn
                              ? 'Nécessite un code de votre application'
                              : 'Scannez un QR code, puis confirmez',
                          divider: true,
                          danger: totpOn,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => totpOn
                                  ? const TotpRevokeScreen()
                                  : const TotpEnrollScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const InfoBanner(
                    text:
                        'Astuce : avec le TOTP activé, vous pouvez réinitialiser votre PIN vous-même en cas d’oubli.',
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.divider = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool divider;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.inkHi;
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
                color: danger ? AppColors.dangerSoft : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppText.ui(
                          size: 14.5, weight: FontWeight.w600, color: fg)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: AppText.ui(size: 12.5, color: AppColors.inkMid)),
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
