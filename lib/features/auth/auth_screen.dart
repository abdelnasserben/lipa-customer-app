import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/phone_input_formatter.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/lipa_brand.dart';
import 'login_controller.dart';
import 'session_controller.dart';

/// The full customer auth surface (login → MFA → PIN setup → expired → locked).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  @override
  void initState() {
    super.initState();
    // If we arrived here due to an expired session, show that variant once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionControllerProvider);
      if (session.expiredNotice) {
        ref.read(loginControllerProvider.notifier).goToStep(
              AuthStep.sessionExpired,
            );
        ref.read(sessionControllerProvider.notifier).clearExpiredNotice();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final step = state.step;

    final (heroTitle, heroSubtitle) = switch (step) {
      AuthStep.login => (
          'Bon retour',
          'Connectez-vous en toute sécurité pour accéder à votre portefeuille.'
        ),
      AuthStep.mfa => (
          'Vérifiez votre identité',
          'Saisissez le code à 6 chiffres de votre application d’authentification.'
        ),
      AuthStep.pinSetup => (
          'Définir votre PIN',
          'Protégez votre compte et vos opérations avec un PIN sécurisé.'
        ),
      AuthStep.forgotPin => (
          'PIN oublié',
          'Réinitialisez votre PIN avec le code de votre application d’authentification.'
        ),
      AuthStep.sessionExpired => (
          'Session expirée',
          'Vous avez été déconnecté afin de protéger votre compte.'
        ),
      AuthStep.locked => (
          'PIN bloqué',
          'Trop de tentatives incorrectes. Réessayez dans 14 minutes.'
        ),
    };

    // The dark hero extends under the real status bar; pad its content down by
    // the status bar inset so nothing sits beneath the system clock.
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Dark hero header.
          Stack(
            children: [
              Container(
                height: 320 + topInset,
                width: double.infinity,
                color: AppColors.nearBlack,
              ),
              // GridBackground is itself a Positioned.fill, so it must sit
              // directly inside the Stack (not nested in the Container above).
              const GridBackground(),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, topInset, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const LipaWordmark(dark: true, size: 44),
                      const SizedBox(height: 36),
                      Text(heroTitle,
                          style: AppText.ui(
                              size: 32,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.8,
                              height: 1.05)),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(heroSubtitle,
                            style: AppText.ui(
                                size: 14.5,
                                color: Colors.white.withValues(alpha: 0.62),
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                left: 0,
                right: 0,
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: switch (step) {
                AuthStep.login => _LoginForm(state: state),
                AuthStep.mfa => _MfaForm(state: state),
                AuthStep.pinSetup => _PinSetupForm(state: state),
                AuthStep.forgotPin => _ForgotPinForm(state: state),
                AuthStep.sessionExpired => const _SessionExpired(),
                AuthStep.locked => const _PinLocked(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({required this.state});
  final LoginState state;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _reveal = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _valid =>
      _phone.text.replaceAll(RegExp(r'\D'), '').length >= 4 &&
      _pin.text.length >= 4;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.pinResetDone) ...[
          const InfoBanner(
            icon: Icons.check_circle_outline,
            kind: PillKind.success,
            text: 'PIN réinitialisé. Connectez-vous avec votre nouveau PIN.',
          ),
          const SizedBox(height: 18),
        ],
        _FieldLabel('Numéro de téléphone'),
        const SizedBox(height: 8),
        _PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FieldLabel('PIN'),
            Text('4 à 8 chiffres',
                style: AppText.ui(size: 12, color: AppColors.inkLow)),
          ],
        ),
        const SizedBox(height: 8),
        _BoxedInput(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pin,
                  obscureText: !_reveal,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  style: AppText.mono(size: 18, letterSpacing: 4),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Saisissez votre PIN',
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _reveal = !_reveal),
                icon: Icon(_reveal ? Icons.visibility_off : Icons.visibility,
                    size: 20, color: AppColors.inkMid),
              ),
            ],
          ),
        ),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 18),
        LipaButton(
          label: 'Se connecter',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _valid
              ? () => ref
                  .read(loginControllerProvider.notifier)
                  .login(phoneNumber: _phone.text, pin: _pin.text)
              : null,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => ref
                  .read(loginControllerProvider.notifier)
                  .goToStep(AuthStep.forgotPin),
              child: Text('PIN oublié ?',
                  style: AppText.ui(
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: AppColors.brand)),
            ),
            Text('Besoin d’aide ?',
                style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
          ],
        ),
        const SizedBox(height: 16),
        LipaCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined,
                  size: 20, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppText.ui(
                        size: 12.5, color: AppColors.inkMid, height: 1.55),
                    children: [
                      TextSpan(
                          text: 'Sécurité renforcée par Lipa. ',
                          style: AppText.ui(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: AppColors.inkHi)),
                      const TextSpan(
                          text:
                              'Votre PIN reste confidentiel et protégé.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (ref.watch(sessionControllerProvider).status ==
            SessionStatus.unknown)
          const SizedBox.shrink(),
      ],
    );
  }
}

/// MFA: a single hidden field backing 6 display cells.
class _MfaForm extends ConsumerStatefulWidget {
  const _MfaForm({required this.state});
  final LoginState state;
  @override
  ConsumerState<_MfaForm> createState() => _MfaFormState();
}

class _MfaFormState extends ConsumerState<_MfaForm> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OtpInput(onChanged: (v) => setState(() => _code = v)),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 18),
        LipaButton(
          label: 'Vérifier et continuer',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _code.length == 6
              ? () =>
                  ref.read(loginControllerProvider.notifier).verifyMfa(_code)
              : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () =>
              ref.read(loginControllerProvider.notifier).goToStep(AuthStep.login),
          child: Text('← Retour à la connexion',
              style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
        ),
      ],
    );
  }
}

class _PinSetupForm extends ConsumerStatefulWidget {
  const _PinSetupForm({required this.state});
  final LoginState state;
  @override
  ConsumerState<_PinSetupForm> createState() => _PinSetupFormState();
}

class _PinSetupFormState extends ConsumerState<_PinSetupForm> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _pin.text.length >= 4 && _pin.text == _confirm.text;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.lock_outline,
          text: 'Configuration unique. Choisissez un PIN de 4 à 8 chiffres.',
        ),
        const SizedBox(height: 18),
        _FieldLabel('Nouveau PIN'),
        const SizedBox(height: 8),
        _PinDigitsInput(controller: _pin, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        _FieldLabel('Confirmer le PIN'),
        const SizedBox(height: 8),
        _PinDigitsInput(
            controller: _confirm, onChanged: (_) => setState(() {})),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 22),
        LipaButton(
          label: 'Enregistrer le PIN',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _valid
              ? () =>
                  ref.read(loginControllerProvider.notifier).setupPin(_pin.text)
              : null,
        ),
      ],
    );
  }
}

/// Forgotten-PIN reset (spec §3.3): phone + current TOTP code + new PIN.
/// Only succeeds for TOTP-enrolled customers — the backend rejects others with
/// `AUTH_PIN_RESET_TOTP_REQUIRED`, surfaced via the form's error line.
class _ForgotPinForm extends ConsumerStatefulWidget {
  const _ForgotPinForm({required this.state});
  final LoginState state;
  @override
  ConsumerState<_ForgotPinForm> createState() => _ForgotPinFormState();
}

class _ForgotPinFormState extends ConsumerState<_ForgotPinForm> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.state.phoneNumber);
  final _newPin = TextEditingController();
  final _confirm = TextEditingController();
  String _code = '';

  @override
  void dispose() {
    _phone.dispose();
    _newPin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid =>
      _phone.text.replaceAll(RegExp(r'\D'), '').length >= 4 &&
      _code.length == 6 &&
      _newPin.text.length >= 4 &&
      _newPin.text == _confirm.text;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBanner(
          icon: Icons.shield_outlined,
          text:
              'Réinitialisation possible uniquement si le TOTP est activé. Sinon, contactez le support Lipa.',
        ),
        const SizedBox(height: 18),
        _FieldLabel('Numéro de téléphone'),
        const SizedBox(height: 8),
        _PhoneInput(controller: _phone, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        _FieldLabel('Nouveau PIN'),
        const SizedBox(height: 8),
        _PinDigitsInput(controller: _newPin, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        _FieldLabel('Confirmer le PIN'),
        const SizedBox(height: 8),
        _PinDigitsInput(
            controller: _confirm, onChanged: (_) => setState(() {})),
        const SizedBox(height: 18),
        _FieldLabel('Code d’authentification (TOTP)'),
        const SizedBox(height: 8),
        _OtpInput(onChanged: (v) => setState(() => _code = v)),
        if (s.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(s.errorMessage!,
              style: AppText.ui(size: 13, color: AppColors.danger)),
        ],
        const SizedBox(height: 22),
        LipaButton(
          label: 'Réinitialiser le PIN',
          size: BtnSize.lg,
          full: true,
          loading: s.submitting,
          onPressed: _valid
              ? () => ref.read(loginControllerProvider.notifier).resetPin(
                    phoneNumber: _phone.text,
                    totpCode: _code,
                    newPin: _newPin.text,
                  )
              : null,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.login),
          child: Text('← Retour à la connexion',
              style: AppText.ui(size: 13.5, color: AppColors.inkMid)),
        ),
      ],
    );
  }
}

class _SessionExpired extends ConsumerWidget {
  const _SessionExpired();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LipaCard(
          padding: const EdgeInsets.all(18),
          radius: AppRadius.lg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warnSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 20, color: AppColors.warn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vous avez été déconnecté',
                        style: AppText.ui(
                            size: 14.5, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'Reconnectez-vous pour continuer à utiliser votre portefeuille Lipa.',
                        style: AppText.ui(
                            size: 13, color: AppColors.inkMid, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LipaButton(
          label: 'Se reconnecter',
          size: BtnSize.lg,
          full: true,
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.login),
        ),
      ],
    );
  }
}

class _PinLocked extends ConsumerWidget {
  const _PinLocked();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Icon(Icons.lock_outline,
                    size: 20, color: AppColors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saisie du PIN bloquée',
                        style: AppText.ui(
                            size: 14.5, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'PIN incorrect saisi 3 fois. Réessayez dans 15 minutes.',
                        style: AppText.ui(
                            size: 13, color: AppColors.inkMid, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LipaButton(
          label: 'Réinitialiser mon PIN',
          variant: BtnVariant.secondary,
          size: BtnSize.lg,
          full: true,
          onPressed: () => ref
              .read(loginControllerProvider.notifier)
              .goToStep(AuthStep.forgotPin),
        ),
      ],
    );
  }
}

// ── small form atoms ──────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: AppText.ui(size: 13, weight: FontWeight.w600));
}

class _BoxedInput extends StatelessWidget {
  const _BoxedInput({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderHi),
        ),
        child: child,
      );
}

class _PhoneInput extends StatelessWidget {
  const _PhoneInput({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
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
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Text('+269',
                style: AppText.mono(size: 15, weight: FontWeight.w600)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.phone,
                inputFormatters: const [ComorianPhoneFormatter()],
                onChanged: onChanged,
                style: AppText.mono(size: 16, letterSpacing: 0.6),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: '300 00 00',
                  hintStyle: AppText.mono(
                      size: 16, letterSpacing: 0.6, color: AppColors.inkFaint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinDigitsInput extends StatelessWidget {
  const _PinDigitsInput({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderHi),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              style: AppText.mono(size: 22, letterSpacing: 6),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isDense: true,
                hintText: '••••',
              ),
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (_, _) => Text('${controller.text.length}/8',
                style: AppText.mono(size: 12.5, color: AppColors.inkLow)),
          ),
        ],
      ),
    );
  }
}

/// Six display cells backed by a single hidden field.
class _OtpInput extends StatefulWidget {
  const _OtpInput({required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Row(
            children: List.generate(6, (i) {
              final filled = i < code.length;
              final active = i == code.length;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 5 ? 10 : 0),
                  child: Container(
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: filled || active
                            ? AppColors.brand
                            : AppColors.borderHi,
                        width: 1.5,
                      ),
                    ),
                    child: Text(filled ? code[i] : '',
                        style: AppText.mono(
                            size: 26, weight: FontWeight.w600)),
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  setState(() {});
                  widget.onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
