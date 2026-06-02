// Backend enums (spec §8). Each parses defensively from its wire string and
// keeps an `unknown` fallback so future values never crash the UI.

enum CustomerStatus {
  pendingKyc,
  active,
  suspended,
  frozen,
  closed,
  unknown;

  static CustomerStatus parse(String? s) => switch (s) {
        'PENDING_KYC' => pendingKyc,
        'ACTIVE' => active,
        'SUSPENDED' => suspended,
        'FROZEN' => frozen,
        'CLOSED' => closed,
        _ => unknown,
      };

  bool get isActive => this == active;
}

enum WalletStatus {
  active,
  frozen,
  suspended,
  closed,
  unknown;

  static WalletStatus parse(String? s) => switch (s) {
        'ACTIVE' => active,
        'FROZEN' => frozen,
        'SUSPENDED' => suspended,
        'CLOSED' => closed,
        _ => unknown,
      };
}

enum TransactionType {
  cashIn,
  payment,
  cashOut,
  cardSale,
  p2pTransfer,
  merchantToMerchant,
  paymentRequest,
  servicePayment,
  commissionPayout,
  reversal,
  unknown;

  static TransactionType parse(String? s) => switch (s) {
        'CASH_IN' => cashIn,
        'PAYMENT' => payment,
        'CASH_OUT' => cashOut,
        'CARD_SALE' => cardSale,
        'P2P_TRANSFER' => p2pTransfer,
        'MERCHANT_TO_MERCHANT' => merchantToMerchant,
        'PAYMENT_REQUEST' => paymentRequest,
        'SERVICE_PAYMENT' => servicePayment,
        'COMMISSION_PAYOUT' => commissionPayout,
        'REVERSAL' => reversal,
        _ => unknown,
      };

  /// Long-form French label (e.g. `Transfert P2P`). Pure-Dart so non-widget
  /// layers (e.g. statement entries) can localize a raw wire token.
  String get frLabel => switch (this) {
        p2pTransfer => 'Transfert P2P',
        cardSale => 'Paiement carte',
        payment => 'Paiement marchand',
        paymentRequest => 'Demande de paiement',
        cashIn => 'Dépôt agent',
        cashOut => 'Retrait agent',
        servicePayment => 'Paiement de facture',
        merchantToMerchant => 'Transfert marchand',
        commissionPayout => 'Commission',
        reversal => 'Annulation',
        unknown => 'Transaction',
      };
}

enum TransactionStatus {
  pending,
  authorized,
  completed,
  declined,
  expired,
  reversed,
  unknown;

  static TransactionStatus parse(String? s) => switch (s) {
        'PENDING' => pending,
        'AUTHORIZED' => authorized,
        'COMPLETED' => completed,
        'DECLINED' => declined,
        'EXPIRED' => expired,
        'REVERSED' => reversed,
        _ => unknown,
      };

  bool get isCompleted => this == completed;
  bool get isDeclined => this == declined;
}

enum CardStatus {
  issued,
  active,
  blocked,
  lost,
  stolen,
  expired,
  closed,
  unknown;

  static CardStatus parse(String? s) => switch (s) {
        'ISSUED' => issued,
        'ACTIVE' => active,
        'BLOCKED' => blocked,
        'LOST' => lost,
        'STOLEN' => stolen,
        'EXPIRED' => expired,
        'CLOSED' => closed,
        _ => unknown,
      };

  bool get isUsable => this == active || this == issued;
}

enum BillPaymentStatus {
  queued,
  inProcessing,
  succeeded,
  failedRefunded,
  failedRetry,
  unknown;

  static BillPaymentStatus parse(String? s) => switch (s) {
        'QUEUED' => queued,
        'IN_PROCESSING' => inProcessing,
        'SUCCEEDED' => succeeded,
        'FAILED_REFUNDED' => failedRefunded,
        'FAILED_RETRY' => failedRetry,
        _ => unknown,
      };

  bool get isCancellable => this == queued;
  bool get hasReceipt => this == succeeded;
}

/// Control-gate outcome for P2P / bill-pay / payment-request pay (spec §7.4).
enum ControlOutcome {
  executed,
  pendingPin,
  pendingConfirmation,
  unknown;

  static ControlOutcome parse(String? s) => switch (s) {
        'EXECUTED' => executed,
        'PENDING_PIN' => pendingPin,
        'PENDING_CONFIRMATION' => pendingConfirmation,
        _ => unknown,
      };
}

enum NotificationCategory {
  transaction,
  billPayment,
  unknown;

  static NotificationCategory parse(String? s) => switch (s) {
        'TRANSACTION' => transaction,
        'BILL_PAYMENT' => billPayment,
        _ => unknown,
      };
}

enum NotificationStatus {
  unread,
  read,
  unknown;

  static NotificationStatus parse(String? s) => switch (s) {
        'UNREAD' => unread,
        'READ' => read,
        _ => unknown,
      };

  bool get isUnread => this == unread;
}

enum EntryType {
  debit,
  credit,
  unknown;

  static EntryType parse(String? s) => switch (s) {
        'DEBIT' => debit,
        'CREDIT' => credit,
        _ => unknown,
      };

  bool get isCredit => this == credit;
}
