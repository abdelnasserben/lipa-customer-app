import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../customer/customer_providers.dart';

/// Limits (design: customer-extras.jsx LimitsScreen). Handles the
/// "not configured" case when /me/limits returns 404 (null).
class LimitsScreen extends ConsumerWidget {
  const LimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(limitsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
              title: 'Plafonds',
              onBack: () => Navigator.pop(context),
              subtitle: limits.maybeWhen(
                  data: (l) => l?.profileName, orElse: () => null),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: limits.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.brand)),
                ),
                error: (e, _) => const InfoBanner(
                  text: 'Impossible de charger vos plafonds.',
                  kind: PillKind.warn,
                ),
                data: (l) {
                  if (l == null) {
                    return const InfoBanner(
                      icon: Icons.info_outline,
                      text:
                          'Plafonds non configurés. Complétez votre KYC chez un agent Lipa pour activer les transferts.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LipaCard(
                        child: Column(
                          children: [
                            if (l.maxTransactionAmount != null)
                              DetailRow(
                                  label: 'Max. par opération',
                                  value:
                                      '${fmtKmfNoUnit(l.maxTransactionAmount!)} KMF',
                                  mono: true),
                            if (l.maxDailyAmount != null)
                              DetailRow(
                                  label: 'Max. quotidien',
                                  value:
                                      '${fmtKmfNoUnit(l.maxDailyAmount!)} KMF',
                                  mono: true),
                            if (l.maxMonthlyAmount != null)
                              DetailRow(
                                  label: 'Max. mensuel',
                                  value:
                                      '${fmtKmfNoUnit(l.maxMonthlyAmount!)} KMF',
                                  mono: true),
                            DetailRow(
                                label: 'Nb. opérations / jour',
                                value: '${l.maxDailyTransactionCount ?? '—'}',
                                mono: true,
                                last: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const InfoBanner(
                        text:
                            'Les plafonds dépendent de votre niveau KYC. Pour les augmenter, complétez le KYC chez un agent Lipa.',
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
