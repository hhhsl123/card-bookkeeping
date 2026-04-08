import 'package:flutter/material.dart';
import '../models/data.dart';

class CardTile extends StatelessWidget {
  final CardItem card;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onCopy;

  const CardTile({super.key, required this.card, required this.selected, required this.onTap, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final isBad = card.bad;
    final isSold = card.sold && !card.bad;

    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    double opacity = 1.0;

    if (isBad) {
      borderColor = Colors.red;
      bgColor = Colors.red.shade50;
      opacity = 0.6;
    } else if (isSold) {
      opacity = 0.7;
      bgColor = Colors.grey.shade100;
    }

    if (selected) {
      borderColor = Theme.of(context).colorScheme.primary;
      if (!isBad) {
        bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.15);
      }
      opacity = 1.0;
    }

    final faceStr = card.face % 1 == 0 ? '¥${card.face.toInt()}' : '¥${card.face}';

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSold && card.soldBy != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(99)),
                  child: Text(card.soldBy!, style: const TextStyle(fontSize: 8, color: Colors.white)),
                ),
              if (isBad)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(99)),
                  child: Text(card.soldPrice > 0 ? '余${card.soldPrice.toInt()}' : '坏卡', style: const TextStyle(fontSize: 8, color: Colors.white)),
                ),
              Text(
                card.label,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(faceStr, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
              if (isSold) Text('已卖', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
              if (onCopy != null)
                GestureDetector(
                  onTap: onCopy,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.copy, size: 12, color: Colors.grey[400]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
