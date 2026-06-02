import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// A single 6-digit TOTP code input (spec: VerifyMfaRequest.code = 6 digits).
class TotpCodeField extends StatefulWidget {
  const TotpCodeField({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<TotpCodeField> createState() => _TotpCodeFieldState();
}

class _TotpCodeFieldState extends State<TotpCodeField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderHi),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: widget.onChanged,
        style: AppText.mono(size: 26, weight: FontWeight.w600, letterSpacing: 8),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: '••••••',
        ),
      ),
    );
  }
}
