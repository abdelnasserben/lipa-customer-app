import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import 'pay_request_screen.dart';

/// Enter a merchant payment-request short code, then look it up (spec §10).
/// A failed lookup returns the same 404 for every reason — we never reveal why.
class PayRequestCodeScreen extends ConsumerStatefulWidget {
  const PayRequestCodeScreen({super.key});

  @override
  ConsumerState<PayRequestCodeScreen> createState() =>
      _PayRequestCodeScreenState();
}

class _PayRequestCodeScreenState extends ConsumerState<PayRequestCodeScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  String get _value => _code.text.trim().toUpperCase();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (_value.length < 4) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lookup =
          await ref.read(customerRepositoryProvider).lookupPaymentRequest(_value);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PayRequestScreen(shortCode: _value, lookup: lookup),
        ),
      );
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
                title: 'Payer un marchand',
                onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Saisissez le code de demande de paiement affiché par le marchand.',
                    style: AppText.ui(
                        size: 13.5, color: AppColors.inkMid, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.borderHi),
                    ),
                    child: TextField(
                      controller: _code,
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _lookup(),
                      style: AppText.mono(
                          size: 26, weight: FontWeight.w600, letterSpacing: 4),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: '4Z9KP2',
                        hintStyle: AppText.mono(
                            size: 26,
                            weight: FontWeight.w600,
                            letterSpacing: 4,
                            color: AppColors.inkFaint),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    InfoBanner(kind: PillKind.declined, text: _error!),
                  ],
                  const SizedBox(height: 18),
                  LipaButton(
                    label: 'Continuer',
                    size: BtnSize.lg,
                    full: true,
                    loading: _loading,
                    onPressed: _value.length >= 4 ? _lookup : null,
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
