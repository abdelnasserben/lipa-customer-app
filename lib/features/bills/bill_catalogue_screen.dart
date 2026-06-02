import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../data/models/bill_payment.dart';
import '../customer/customer_providers.dart';
import 'bill_initiate_screen.dart';

/// Bill-pay catalogue: pick a provider → pick a service (spec §10.5).
/// Only reachable when the feature is on (the entry point is gated by
/// [billPayEnabledProvider]).
class BillCatalogueScreen extends ConsumerWidget {
  const BillCatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(billCatalogueProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ScreenHeader(
                title: 'Payer une facture',
                onBack: () => Navigator.pop(context)),
            Expanded(
              child: catalogue.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
                error: (_, _) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: InfoBanner(
                    kind: PillKind.warn,
                    text: 'Impossible de charger les fournisseurs.',
                  ),
                ),
                data: (providers) {
                  if (providers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: InfoBanner(
                        text:
                            'Aucun fournisseur disponible pour le moment.',
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async => ref.invalidate(billCatalogueProvider),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final p in providers) _ProviderCard(provider: p),
                      ],
                    ),
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

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider});
  final BillCatalogProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LipaCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.receipt_long,
                        color: AppColors.brandDeep, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(provider.providerName,
                            style: AppText.ui(
                                size: 15.5, weight: FontWeight.w700)),
                        if (provider.announcedDelayHours != null)
                          Text(
                              'Traité sous ${provider.announcedDelayHours}h ouvrées',
                              style: AppText.ui(
                                  size: 12, color: AppColors.inkMid)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < provider.services.length; i++)
              _ServiceRow(
                provider: provider,
                service: provider.services[i],
                divider: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.provider,
    required this.service,
    this.divider = false,
  });
  final BillCatalogProvider provider;
  final BillService service;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              BillInitiateScreen(provider: provider, service: service),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: divider
              ? const Border(top: BorderSide(color: AppColors.border))
              : null,
        ),
        child: Row(
          children: [
            Icon(_categoryIcon(service.category),
                size: 20, color: AppColors.inkMid),
            const SizedBox(width: 12),
            Expanded(
              child: Text(service.name,
                  style: AppText.ui(size: 14.5, weight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.inkLow),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
        'ELECTRICITY' => Icons.bolt,
        'WATER' => Icons.water_drop,
        'TV' => Icons.tv,
        'TELECOM' => Icons.call,
        'AIRTIME' => Icons.smartphone,
        'INTERNET' => Icons.wifi,
        _ => Icons.receipt_long,
      };
}
