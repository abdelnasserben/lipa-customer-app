import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/card.dart';
import '../customer/customer_providers.dart';
import 'cards_screen.dart';

/// Card detail + report lost/stolen (design: customer-extras.jsx CardDetail).
class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.card});
  final CustomerCard card;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  late CustomerCard _card = widget.card;
  bool _busy = false;

  Future<void> _report({required bool stolen}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(stolen ? 'Signaler la carte volée' : 'Signaler la carte perdue',
            style: AppText.ui(size: 17, weight: FontWeight.w700)),
        content: Text(
          stolen
              ? 'La carte sera immédiatement bloquée. Cette action est irréversible.'
              : 'La carte sera bloquée. Vous pourrez en demander une nouvelle auprès d’un agent Lipa.',
          style: AppText.ui(size: 14, color: AppColors.inkMid, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Annuler',
                style: AppText.ui(size: 14, color: AppColors.inkMid)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Confirmer',
                style: AppText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(customerRepositoryProvider);
      final updated = stolen
          ? await repo.reportCardStolen(_card.id)
          : await repo.reportCardLost(_card.id);
      ref.invalidate(cardsProvider);
      if (mounted) setState(() => _card = updated);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(frenchMessageForError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _card;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ScreenHeader(
                title: 'Détail carte', onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardChip(card: c),
                  const SizedBox(height: 14),
                  LipaCard(
                    child: Column(
                      children: [
                        DetailRow(
                            label: 'ID carte',
                            value: shortId(c.id),
                            mono: true,
                            copy: true),
                        DetailRow(
                            label: 'Émise le',
                            value: DateFormat('dd MMM yyyy', 'fr_FR')
                                .format(c.issuedAt)),
                        if (c.lastUsedAt != null)
                          DetailRow(
                              label: 'Dernière utilisation',
                              value: fmtDateTimeFr(c.lastUsedAt!)),
                        DetailRow(
                            label: 'PIN',
                            value: c.pinEnabled ? 'Activé' : 'Désactivé',
                            last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('EN CAS DE PROBLÈME',
                      style: AppText.ui(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.inkLow,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  LipaCard(
                    child: Column(
                      children: [
                        _ActionRow(
                          title: 'Signaler perdue',
                          subtitle: 'Carte égarée, introuvable',
                          kind: PillKind.warn,
                          enabled: c.status.isUsable && !_busy,
                          onTap: () => _report(stolen: false),
                        ),
                        _ActionRow(
                          title: 'Signaler volée',
                          subtitle: 'Carte volée — bloquez-la maintenant',
                          kind: PillKind.declined,
                          divider: true,
                          enabled: c.status.isUsable && !_busy,
                          onTap: () => _report(stolen: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const InfoBanner(
                    text:
                        'Les cartes de remplacement sont délivrées en personne par un agent Lipa.',
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.onTap,
    required this.enabled,
    this.divider = false,
  });

  final String title;
  final String subtitle;
  final PillKind kind;
  final VoidCallback onTap;
  final bool enabled;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      PillKind.warn => (AppColors.warnSoft, AppColors.warn),
      PillKind.declined => (AppColors.dangerSoft, AppColors.danger),
      _ => (AppColors.surfaceAlt, AppColors.inkHi),
    };
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: divider
                ? const Border(top: BorderSide(color: AppColors.border))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.warning_amber_rounded, size: 20, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppText.ui(
                            size: 14, weight: FontWeight.w600, color: fg)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            AppText.ui(size: 12.5, color: AppColors.inkMid)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkLow),
            ],
          ),
        ),
      ),
    );
  }
}
