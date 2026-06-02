import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import 'security_controller.dart';
import 'totp_code_field.dart';

/// Revoke TOTP (spec §3.3 — step-up with a current 6-digit code).
class TotpRevokeScreen extends ConsumerStatefulWidget {
  const TotpRevokeScreen({super.key});

  @override
  ConsumerState<TotpRevokeScreen> createState() => _TotpRevokeScreenState();
}

class _TotpRevokeScreenState extends ConsumerState<TotpRevokeScreen> {
  String _code = '';
  bool _loading = false;
  String? _error;

  Future<void> _revoke() async {
    if (_code.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(securityActionsProvider).revokeTotp(_code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TOTP désactivé.')),
      );
      Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() => _error = frenchMessageForError(e));
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
                title: 'Désactiver le TOTP',
                onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const InfoBanner(
                    kind: PillKind.warn,
                    icon: Icons.warning_amber_rounded,
                    text:
                        'Sans TOTP, vous ne pourrez plus réinitialiser votre PIN vous-même en cas d’oubli.',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Saisissez un code à 6 chiffres de votre application pour confirmer.',
                    style: AppText.ui(
                        size: 13.5, color: AppColors.inkMid, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  TotpCodeField(
                      onChanged: (c) => setState(() {
                            _code = c;
                            _error = null;
                          })),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InfoBanner(kind: PillKind.declined, text: _error!),
                  ],
                  const SizedBox(height: 20),
                  LipaButton(
                    label: 'Désactiver le TOTP',
                    variant: BtnVariant.danger,
                    size: BtnSize.lg,
                    full: true,
                    loading: _loading,
                    onPressed: _code.length == 6 ? _revoke : null,
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
