import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/common.dart';
import '../../data/models/transaction.dart';
import '../customer/customer_providers.dart';
import 'transaction_detail_screen.dart';
import 'tx_row.dart';

/// Activity list, grouped by day, with in/out filter chips
/// (design: customer.jsx CustomerActivity — transactions segment).
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionsProvider);
    return Column(
      children: [
        const ScreenHeader(title: 'Activité'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              for (final f in const [
                ('all', 'Toutes'),
                ('in', 'Entrées'),
                ('out', 'Sorties'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _Chip(
                    label: f.$2,
                    active: _filter == f.$1,
                    onTap: () => setState(() => _filter = f.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: txs.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.brand)),
            error: (e, _) => Center(
              child: Text('Impossible de charger l’activité.',
                  style: AppText.ui(size: 13, color: AppColors.inkMid)),
            ),
            data: (list) {
              final filtered = switch (_filter) {
                'in' => list.where((t) => t.isIncoming).toList(),
                'out' => list.where((t) => !t.isIncoming).toList(),
                _ => list,
              };
              if (filtered.isEmpty) {
                return Center(
                  child: Text('Aucune transaction',
                      style: AppText.ui(size: 14, color: AppColors.inkMid)),
                );
              }
              final groups = _groupByDay(filtered);
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(transactionsProvider);
                  await ref.read(transactionsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    for (final entry in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                        child: Text(entry.key.toUpperCase(),
                            style: AppText.ui(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: AppColors.inkLow,
                                letterSpacing: 1)),
                      ),
                      LipaCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < entry.value.length; i++)
                              TxRow(
                                tx: entry.value[i],
                                divider: i > 0,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(
                                        tx: entry.value[i]),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, List<CustomerTransaction>>> _groupByDay(
      List<CustomerTransaction> txs) {
    final now = DateTime.now();
    final map = <String, List<CustomerTransaction>>{};
    for (final t in txs) {
      final d = t.createdAt.toLocal();
      final diff = DateUtils.dateOnly(now).difference(DateUtils.dateOnly(d)).inDays;
      final key = diff == 0
          ? 'Aujourd’hui'
          : diff == 1
              ? 'Hier'
              : DateFormat('EEE dd MMM', 'fr_FR').format(d);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map.entries.toList();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.inkHi : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: active ? AppColors.inkHi : AppColors.border),
        ),
        child: Text(label,
            style: AppText.ui(
                size: 12.5,
                weight: FontWeight.w600,
                color: active ? Colors.white : AppColors.inkMid)),
      ),
    );
  }
}
