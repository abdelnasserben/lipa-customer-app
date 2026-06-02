import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/api_error.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/bill_payment.dart';
import '../../data/models/enums.dart';
import '../customer/customer_providers.dart';
import 'bill_final_receipt_screen.dart';

/// Bill-payment detail + status timeline (spec §10.5 / §7.4a). Shows
/// "Annuler" only on QUEUED and "Reçu" only on SUCCEEDED.
class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(billPaymentProvider(widget.id));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: detail.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.brand)),
          error: (e, _) => _ErrorBody(
            message: e is ApiError && e.isNotFound
                ? 'Ce paiement est introuvable.'
                : 'Impossible de charger ce paiement.',
          ),
          data: (bp) => _Body(
            bp: bp,
            cancelling: _cancelling,
            onCancel: () => _cancel(bp),
            onReceipt: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BillFinalReceiptScreen(id: bp.id),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(CustomerBillPayment bp) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Annuler ce paiement ?',
            style: AppText.ui(size: 17, weight: FontWeight.w700)),
        content: Text(
            'Les fonds (${fmtKmfNoUnit(bp.amount + bp.feeAmount)} KMF) vous seront restitués.',
            style: AppText.ui(size: 14, color: AppColors.inkMid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Non', style: AppText.ui(size: 14, color: AppColors.inkMid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Annuler le paiement',
                style: AppText.ui(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(customerRepositoryProvider).cancelBillPayment(bp.id);
      ref.invalidate(billPaymentProvider(widget.id));
      ref.invalidate(billPaymentsProvider);
      ref.invalidate(balanceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paiement annulé. Fonds restitués.')),
        );
      }
    } on ApiError catch (e) {
      // Likely INVALID_TRANSITION — an operator already took it. Refresh.
      ref.invalidate(billPaymentProvider(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(frenchMessageForError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.bp,
    required this.cancelling,
    required this.onCancel,
    required this.onReceipt,
  });

  final CustomerBillPayment bp;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ScreenHeader(title: 'Facture', onBack: () => Navigator.pop(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LipaCard(
                radius: AppRadius.card,
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(bp.providerName,
                        style: AppText.ui(size: 16, weight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: fmtKmfNoUnit(bp.amount),
                          style:
                              AppText.mono(size: 40, weight: FontWeight.w600)),
                      TextSpan(
                          text: '  KMF',
                          style: AppText.mono(
                              size: 16, color: AppColors.inkLow)),
                    ])),
                    const SizedBox(height: 12),
                    BillStatusPill(status: bp.status),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LipaCard(
                child: Column(
                  children: [
                    DetailRow(label: 'Référence', value: bp.reference, mono: true),
                    DetailRow(
                        label: 'Montant',
                        value: '${fmtKmfNoUnit(bp.amount)} KMF',
                        mono: true),
                    if (bp.feeAmount > 0)
                      DetailRow(
                          label: 'Frais',
                          value: '${fmtKmfNoUnit(bp.feeAmount)} KMF',
                          mono: true),
                    if (bp.externalReference != null)
                      DetailRow(
                          label: 'N° fournisseur',
                          value: bp.externalReference!,
                          mono: true,
                          copy: true),
                    DetailRow(
                        label: 'Créée le',
                        value: fmtDateTimeFr(bp.createdAt),
                        last: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Timeline(bp: bp),
              if (bp.status == BillPaymentStatus.failedRefunded &&
                  bp.refundReason != null) ...[
                const SizedBox(height: 16),
                InfoBanner(
                  kind: PillKind.warn,
                  text: 'Remboursée : ${bp.refundReason}',
                ),
              ],
              const SizedBox(height: 18),
              if (bp.status.hasReceipt)
                LipaButton(
                  label: 'Voir le reçu',
                  size: BtnSize.lg,
                  full: true,
                  icon: const Icon(Icons.receipt_long),
                  onPressed: onReceipt,
                ),
              if (bp.status.isCancellable) ...[
                const SizedBox(height: 10),
                LipaButton(
                  label: 'Annuler le paiement',
                  variant: BtnVariant.dangerOutline,
                  size: BtnSize.lg,
                  full: true,
                  loading: cancelling,
                  onPressed: onCancel,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// created → queued → in processing → finalised, rendered from the populated
/// timestamps (spec §7.4a).
class _Timeline extends StatelessWidget {
  const _Timeline({required this.bp});
  final CustomerBillPayment bp;

  @override
  Widget build(BuildContext context) {
    final terminalFailed = bp.status == BillPaymentStatus.failedRefunded;
    final steps = <_Step>[
      _Step('Créée', bp.createdAt),
      _Step('En file', bp.queuedAt),
      _Step('En traitement', bp.processingStartedAt),
      _Step(
        terminalFailed ? 'Remboursée' : 'Payée',
        bp.completedAt,
      ),
    ];
    return LipaCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              _TimelineRow(
                step: steps[i],
                isLast: i == steps.length - 1,
                failed: terminalFailed && i == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step(this.label, this.at);
  final String label;
  final DateTime? at;
  bool get done => at != null;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.failed,
  });
  final _Step step;
  final bool isLast;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = !step.done
        ? AppColors.inkLow
        : failed
            ? AppColors.warn
            : AppColors.brand;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: step.done ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
                child: step.done
                    ? Icon(failed ? Icons.close : Icons.check,
                        size: 10, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: step.done ? color : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label,
                    style: AppText.ui(
                        size: 14,
                        weight: step.done ? FontWeight.w600 : FontWeight.w500,
                        color: step.done ? AppColors.inkHi : AppColors.inkLow)),
                if (step.at != null)
                  Text(fmtDateTimeFr(step.at!),
                      style: AppText.ui(size: 12, color: AppColors.inkMid)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScreenHeader(title: 'Facture', onBack: () => Navigator.pop(context)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: InfoBanner(kind: PillKind.warn, text: message),
        ),
      ],
    );
  }
}
