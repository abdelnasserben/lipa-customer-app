import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'core/widgets/lipa_brand.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/session_controller.dart';
import 'features/customer/customer_shell.dart';

/// Root widget. Switches between the auth surface and the customer shell based
/// on session state. There is no GoRouter URL tree here because the customer
/// app is a single-actor mobile shell with in-tab navigation; the top-level
/// branch is purely auth vs. authenticated.
class LipaApp extends ConsumerWidget {
  const LipaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return MaterialApp(
      title: 'Lipa',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: switch (session.status) {
        SessionStatus.unknown => const _Splash(),
        SessionStatus.unauthenticated => const AuthScreen(),
        SessionStatus.authenticated => const CustomerShell(),
      },
    );
  }
}

/// First-frame splash shown while the session is resolving. Kept deliberately
/// simple and on-brand: the warm Lipa surface with the wordmark centred and a
/// thin progress hint below — a seamless continuation of the native launch
/// screen (same #F6F4EF background), never a black screen.
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LipaWordmark(size: 44),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
