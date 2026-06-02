import 'package:flutter/widgets.dart';

import '../../data/models/enums.dart';
import 'common.dart';

/// French status pill for transactions (spec/design mapping).
class TxStatusPill extends StatelessWidget {
  const TxStatusPill({super.key, required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (kind, label) = switch (status) {
      TransactionStatus.completed => (PillKind.success, 'Effectué'),
      TransactionStatus.pending => (PillKind.pending, 'En attente'),
      TransactionStatus.authorized => (PillKind.info, 'Autorisé'),
      TransactionStatus.declined => (PillKind.declined, 'Refusé'),
      TransactionStatus.expired => (PillKind.pending, 'Expiré'),
      TransactionStatus.reversed => (PillKind.warn, 'Annulé'),
      TransactionStatus.unknown => (PillKind.neutral, '—'),
    };
    return StatusPill(label: label, kind: kind);
  }
}

/// French status pill for bill payments.
class BillStatusPill extends StatelessWidget {
  const BillStatusPill({super.key, required this.status});
  final BillPaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (kind, label) = switch (status) {
      BillPaymentStatus.queued => (PillKind.pending, 'En file'),
      BillPaymentStatus.inProcessing => (PillKind.info, 'En traitement'),
      BillPaymentStatus.succeeded => (PillKind.success, 'Payée'),
      BillPaymentStatus.failedRefunded => (PillKind.warn, 'Remboursée'),
      BillPaymentStatus.failedRetry => (PillKind.warn, 'À réessayer'),
      BillPaymentStatus.unknown => (PillKind.neutral, '—'),
    };
    return StatusPill(label: label, kind: kind);
  }
}

/// French label for a transaction type (long form).
String typeLabelFr(TransactionType t) => t.frLabel;

/// French label for a transaction status (pure Dart, mirrors [TxStatusPill]
/// so non-widget layers — e.g. the receipt PDF/text — can localize it).
String statusLabelFr(TransactionStatus s) => switch (s) {
      TransactionStatus.completed => 'Effectué',
      TransactionStatus.pending => 'En attente',
      TransactionStatus.authorized => 'Autorisé',
      TransactionStatus.declined => 'Refusé',
      TransactionStatus.expired => 'Expiré',
      TransactionStatus.reversed => 'Annulé',
      TransactionStatus.unknown => '—',
    };

/// Short French label for a transaction row.
String typeRowLabelFr(TransactionType t, {required bool incoming}) =>
    switch (t) {
      TransactionType.p2pTransfer => incoming ? 'Reçu' : 'Envoyé',
      TransactionType.cardSale => 'Paiement carte',
      TransactionType.payment => 'Paiement',
      TransactionType.paymentRequest => 'Demande de paiement',
      TransactionType.cashIn => 'Dépôt',
      TransactionType.cashOut => 'Retrait',
      TransactionType.servicePayment => 'Facture',
      _ => typeLabelFr(t),
    };
