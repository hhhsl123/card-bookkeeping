import 'package:flutter/material.dart';

import '../models/data.dart';

class CardRecordTile extends StatelessWidget {
  const CardRecordTile({
    super.key,
    required this.card,
    required this.costText,
    this.onCopy,
    this.onBad,
    this.onRestore,
    this.onArchive,
  });

  final CardItem card;
  final String costText;
  final VoidCallback? onCopy;
  final VoidCallback? onBad;
  final VoidCallback? onRestore;
  final VoidCallback? onArchive;

  Color _statusColor(BuildContext context) {
    switch (card.status) {
      case CardStatus.available:
        return Theme.of(context).colorScheme.primary;
      case CardStatus.picked:
        return Colors.green.shade700;
      case CardStatus.bad:
        return Colors.red.shade700;
      case CardStatus.cleared:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        color: statusColor.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  card.status.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            card.secret.isEmpty ? '无卡密' : card.secret,
            style: TextStyle(color: Colors.grey.shade700, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          Text('面值 ${card.face % 1 == 0 ? card.face.toInt() : card.face} · 成本 $costText'),
          if (card.statusBy != null) ...[
            const SizedBox(height: 6),
            Text(
              '处理人 ${card.statusBy}${card.actualBalance > 0 ? ' · 余额 ${card.actualBalance}' : ''}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onCopy != null)
                OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制'),
                ),
              if (card.isAvailable && onBad != null)
                FilledButton.tonalIcon(
                  onPressed: onBad,
                  icon: const Icon(Icons.warning_amber_rounded, size: 16),
                  label: const Text('坏卡'),
                ),
              if (!card.isAvailable && onRestore != null)
                OutlinedButton.icon(
                  onPressed: onRestore,
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('恢复'),
                ),
              if (onArchive != null)
                OutlinedButton.icon(
                  onPressed: onArchive,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('移除'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
