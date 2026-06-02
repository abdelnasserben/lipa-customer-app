import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/lipa_brand.dart';
import '../../data/repositories/auth_repository.dart';
import 'security_controller.dart';
import 'totp_code_field.dart';

/// TOTP enrollment (spec §3.3): start setup → display secret/QR → confirm with
/// the first 6-digit code.
class TotpEnrollScreen extends ConsumerStatefulWidget {
  const TotpEnrollScreen({super.key});

  @override
  ConsumerState<TotpEnrollScreen> createState() => _TotpEnrollScreenState();
}

class _TotpEnrollScreenState extends ConsumerState<TotpEnrollScreen> {
  late Future<TotpSetup> _setup;
  String _code = '';
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup = ref.read(securityActionsProvider).startTotpSetup();
  }

  Future<void> _confirm() async {
    if (_code.length != 6) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await ref.read(securityActionsProvider).confirmTotp(_code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('TOTP activé.')),
      );
      Navigator.pop(context);
    } on ApiError catch (e) {
      setState(() => _error = frenchMessageForError(e));
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue.');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: FutureBuilder<TotpSetup>(
          future: _setup,
          builder: (context, snap) {
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ScreenHeader(
                    title: 'Activer le TOTP',
                    onBack: () => Navigator.pop(context)),
                if (snap.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.brand)),
                  )
                else if (snap.hasError)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: InfoBanner(
                      kind: PillKind.warn,
                      text: 'Impossible de démarrer l’enrôlement TOTP.',
                    ),
                  )
                else
                  _Content(
                    setup: snap.data!,
                    code: _code,
                    confirming: _confirming,
                    error: _error,
                    onCode: (c) => setState(() {
                      _code = c;
                      _error = null;
                    }),
                    onConfirm: _confirm,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.setup,
    required this.code,
    required this.confirming,
    required this.error,
    required this.onCode,
    required this.onConfirm,
  });

  final TotpSetup setup;
  final String code;
  final bool confirming;
  final String? error;
  final ValueChanged<String> onCode;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '1. Scannez ce QR code avec votre application d’authentification, ou saisissez la clé manuellement.',
            style:
                AppText.ui(size: 13.5, color: AppColors.inkMid, height: 1.5),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: const FakeQr(size: 170),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: setup.secret));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Clé copiée.')),
              );
            },
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(setup.secret,
                        style: AppText.mono(
                            size: 15, weight: FontWeight.w600, letterSpacing: 1)),
                  ),
                  const Icon(Icons.copy_rounded,
                      size: 16, color: AppColors.inkLow),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '2. Saisissez le code à 6 chiffres généré par l’application.',
            style:
                AppText.ui(size: 13.5, color: AppColors.inkMid, height: 1.5),
          ),
          const SizedBox(height: 14),
          TotpCodeField(onChanged: onCode),
          if (error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(kind: PillKind.declined, text: error!),
          ],
          const SizedBox(height: 20),
          LipaButton(
            label: 'Confirmer & activer',
            size: BtnSize.lg,
            full: true,
            loading: confirming,
            onPressed: code.length == 6 ? onConfirm : null,
          ),
        ],
      ),
    );
  }
}
