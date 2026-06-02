import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/lipa_brand.dart';
import '../../data/models/card.dart';
import '../../data/models/enums.dart';
import '../customer/customer_providers.dart';
import 'card_detail_screen.dart';

/// Cards list (design: customer-extras.jsx CardsList).
class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Cartes'),
            Expanded(
              child: cards.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.brand)),
                error: (e, _) => Center(
                  child: Text('Impossible de charger les cartes.',
                      style: AppText.ui(size: 13, color: AppColors.inkMid)),
                ),
                data: (list) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    CardDetailScreen(card: c)),
                          ),
                          child: CardChip(card: c),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                            color: AppColors.borderHi,
                            style: BorderStyle.solid),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.surfaceAlt,
                            child: Icon(Icons.add, color: AppColors.inkMid),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Besoin d’une nouvelle carte ?',
                                    style: AppText.ui(
                                        size: 14, weight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                    'Les cartes sont délivrées en personne par un agent Lipa.',
                                    style: AppText.ui(
                                        size: 12.5,
                                        color: AppColors.inkMid,
                                        height: 1.5)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dark card visual (design: customer-extras.jsx CardChip).
class CardChip extends StatelessWidget {
  const CardChip({super.key, required this.card});
  final CustomerCard card;

  @override
  Widget build(BuildContext context) {
    final statusFr = _statusFr(card.status);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      child: Stack(
        children: [
          Container(
            color: card.status.isUsable
                ? AppColors.nearBlack
                : const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CARTE ${card.cardType.toUpperCase()}',
                              style: AppText.ui(
                                  size: 11.5,
                                  weight: FontWeight.w600,
                                  color: Colors.white54,
                                  letterSpacing: 1)),
                          const SizedBox(height: 28),
                          Text('•••• •••• •••• ${card.last4}',
                              style: AppText.mono(
                                  size: 21,
                                  color: Colors.white,
                                  letterSpacing: 3)),
                        ],
                      ),
                    ),
                    const LipaMark(size: 36, dark: true),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EXPIRE',
                              style: AppText.ui(
                                  size: 10.5,
                                  color: Colors.white54,
                                  letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(
                              DateFormat('MM/yy').format(card.expiresAt),
                              style: AppText.mono(
                                  size: 14, color: Colors.white)),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: statusFr,
                      kind: card.status == CardStatus.active
                          ? PillKind.success
                          : PillKind.warn,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const GridBackground(),
        ],
      ),
    );
  }
}

String _statusFr(CardStatus s) => switch (s) {
      CardStatus.active => 'Active',
      CardStatus.blocked => 'Bloquée',
      CardStatus.lost => 'Perdue',
      CardStatus.stolen => 'Volée',
      CardStatus.expired => 'Expirée',
      CardStatus.closed => 'Fermée',
      CardStatus.issued => 'Émise',
      CardStatus.unknown => '—',
    };
