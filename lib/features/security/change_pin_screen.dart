import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import 'security_controller.dart';

/// Change the auth PIN (spec §3.3 — `PUT /auth/customer/auth-pin`).
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid => isValidPinChange(
        currentPin: _current.text,
        newPin: _next.text,
        confirmPin: _confirm.text,
      );

  Future<void> _submit() async {
    // Re-check frontally so we never spend an API call on a change the backend
    // would reject (mismatch, same-as-current, bad length).
    final err = pinChangeError(
      currentPin: _current.text,
      newPin: _next.text,
      confirmPin: _confirm.text,
    );
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(securityActionsProvider).changePin(
            currentPin: _current.text,
            newPin: _next.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN mis à jour.')),
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
                title: 'Changer le PIN', onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PinField(
                    label: 'PIN actuel',
                    controller: _current,
                    onChanged: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                  _PinField(
                    label: 'Nouveau PIN',
                    controller: _next,
                    onChanged: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                  _PinField(
                    label: 'Confirmer le nouveau PIN',
                    controller: _confirm,
                    onChanged: () => setState(() => _error = null),
                  ),
                  const SizedBox(height: 6),
                  Text('4 à 8 chiffres, différent du PIN actuel.',
                      style: AppText.ui(size: 12, color: AppColors.inkMid)),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InfoBanner(kind: PillKind.declined, text: _error!),
                  ],
                  const SizedBox(height: 20),
                  LipaButton(
                    label: 'Mettre à jour',
                    size: BtnSize.lg,
                    full: true,
                    loading: _loading,
                    onPressed: _valid ? _submit : null,
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

class _PinField extends StatelessWidget {
  const _PinField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: AppText.ui(
                size: 11.5,
                weight: FontWeight.w600,
                color: AppColors.inkLow,
                letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderHi),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            onChanged: (_) => onChanged(),
            style: AppText.mono(size: 20, letterSpacing: 6),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: '••••',
            ),
          ),
        ),
      ],
    );
  }
}
