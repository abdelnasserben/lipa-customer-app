import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/status_pills.dart';
import '../../data/models/enums.dart';
import '../../data/models/transaction.dart';

/// A single transaction row (design: customer.jsx TxRow).
class TxRow extends StatelessWidget {
  const TxRow({super.key, required this.tx, this.onTap, this.divider = false});

  final CustomerTransaction tx;
  final VoidCallback? onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final positive = tx.isIncoming;
    final declined = tx.status.isDeclined;
    final title = tx.label ?? tx.counterparty ?? typeLabelFr(tx.type);
    return InkWell(
      onTap: onTap,
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: positive ? AppColors.brandSoft : const Color(0xFFF1EFE8),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                positive ? Icons.south_west : Icons.north_east,
                size: 18,
                color: positive ? AppColors.brandDeep : AppColors.inkHi,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 14, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${typeRowLabelFr(tx.type, incoming: positive)} · ${fmtTimeFr(tx.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(size: 12, color: AppColors.inkMid),
                        ),
                      ),
                      if (tx.status != TransactionStatus.completed) ...[
                        const SizedBox(width: 6),
                        TxStatusPill(status: tx.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${positive ? '+' : '−'}${fmtKmfNoUnit(tx.requestedAmount)}',
                  style: AppText.mono(
                    size: 14.5,
                    weight: FontWeight.w600,
                    color: declined
                        ? AppColors.inkLow
                        : positive
                            ? AppColors.brandDeep
                            : AppColors.inkHi,
                  ).copyWith(
                    decoration:
                        declined ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text('KMF',
                    style: AppText.mono(size: 11, color: AppColors.inkLow)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
