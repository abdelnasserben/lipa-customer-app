import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/transaction_receipt.dart';
import '../../core/widgets/common.dart';
import '../../data/models/transaction.dart';

/// Ledger statement (spec §10.2): a date window + the ledger entries with their
/// running balance.
class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({super.key});

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(_statementProvider(_range));
    final loaded = entries.asData?.value;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Relevé',
              onBack: () => Navigator.pop(context),
              action: CircleButton(
                onTap: (loaded == null || loaded.isEmpty)
                    ? null
                    : () => _downloadPdf(loaded),
                child: Icon(
                  Icons.download,
                  size: 20,
                  color: (loaded == null || loaded.isEmpty)
                      ? AppColors.inkLow
                      : AppColors.inkHi,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickRange,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderHi),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16, color: AppColors.inkMid),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _range == null
                                    ? 'Toute la période'
                                    : '${_fmt(_range!.start)} – ${_fmt(_range!.end)}',
                                style: AppText.ui(size: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_range != null) ...[
                    const SizedBox(width: 8),
                    CircleButton(
                      onTap: () => setState(() => _range = null),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: entries.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.brand)),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: InfoBanner(
                    kind: PillKind.warn,
                    text: _errorText(err),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: InfoBanner(
                          text: 'Aucune écriture sur cette période.'),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async =>
                        ref.invalidate(_statementProvider(_range)),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _EntryRow(entry: list[i]),
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

  String _fmt(DateTime d) => DateFormat('dd/MM', 'fr_FR').format(d);

  /// Surfaces the backend's real cause. For unmapped codes (e.g. a date-window
  /// `VALIDATION_INVALID_FORMAT`) we append the raw code so it's diagnosable in
  /// real mode instead of being hidden behind a generic message.
  String _errorText(Object err) {
    if (err is! ApiError) return 'Impossible de charger votre relevé.';
    final msg = frenchMessageForError(err);
    final isGeneric = err.message == null &&
        msg == 'Une erreur est survenue. Réessayez.';
    return isGeneric ? '$msg (${err.code})' : msg;
  }

  /// Generates the statement PDF for the currently-loaded entries and opens
  /// the system print/preview sheet (save/share from there).
  Future<void> _downloadPdf(List<StatementEntry> entries) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(
        onLayout: (_) => statementPdfBytes(
          entries,
          from: _range?.start,
          to: _range?.end,
        ),
        name: 'releve-lipa.pdf',
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de générer le relevé PDF.')),
      );
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});
  final StatementEntry entry;

  @override
  Widget build(BuildContext context) {
    final credit = entry.isCredit;
    return LipaCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: credit ? AppColors.brandSoft : AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                credit ? Icons.south_west : Icons.north_east,
                size: 18,
                color: credit ? AppColors.brandDeep : AppColors.inkMid,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.displayDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(fmtDateTimeFr(entry.postedAt),
                      style: AppText.ui(size: 12, color: AppColors.inkMid)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${credit ? '+' : '−'}${fmtKmfNoUnit(entry.amount)}',
                  style: AppText.mono(
                    size: 14.5,
                    weight: FontWeight.w600,
                    color: credit ? AppColors.brandDeep : AppColors.inkHi,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Solde ${fmtKmfNoUnit(entry.runningBalance)}',
                    style: AppText.mono(size: 11, color: AppColors.inkLow)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Statement entries for the chosen window. A null range = full history.
///
/// The backend binds `from`/`to` as ISO-8601 `Instant`s (date-time), so a bare
/// `yyyy-MM-dd` fails to parse and — since the params are optional — is silently
/// dropped, returning everything. We send full UTC instants and make the window
/// inclusive of the last day by ending at the start of the day *after* `end`.
final _statementProvider = FutureProvider.autoDispose
    .family<List<StatementEntry>, DateTimeRange?>((ref, range) async {
  // The picker yields local midnight; convert to UTC so the boundary is exact.
  String? iso(DateTime? d) => d?.toUtc().toIso8601String();
  final from = range == null
      ? null
      : DateTime(range.start.year, range.start.month, range.start.day);
  // Exclusive upper bound at the next midnight → the whole `end` day is covered.
  final to = range == null
      ? null
      : DateTime(range.end.year, range.end.month, range.end.day + 1);
  final page = await ref.watch(customerRepositoryProvider).getStatements(
        from: iso(from),
        to: iso(to),
      );
  return page.items;
});
