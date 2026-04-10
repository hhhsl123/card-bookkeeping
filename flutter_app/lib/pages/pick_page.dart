import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/data.dart';
import '../providers/app_provider.dart';
import '../services/clipboard_helper.dart';
import '../widgets/section_card.dart';

class PickPage extends StatefulWidget {
  const PickPage({super.key});

  @override
  State<PickPage> createState() => _PickPageState();
}

class _PickPageState extends State<PickPage> {
  final Map<double, int> _counts = {};

  String _fmt(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  /// Build face-value groups from all active batches.
  Map<double, List<CardItem>> _groupByFace(AppData data) {
    final groups = <double, List<CardItem>>{};
    for (final batch in data.activeBatches) {
      for (final card in batch.availableCards) {
        groups.putIfAbsent(card.face, () => []).add(card);
      }
    }
    return Map.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  Future<void> _pick(double face, int count) async {
    final provider = context.read<AppProvider>();
    final cards = await provider.quickPick(face, count);
    if (!mounted) return;
    if (cards.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有足够的可用卡')));
      return;
    }
    final text = cards
        .map((card) =>
            '${card.label}${card.secret.isNotEmpty ? ' ${card.secret}' : ''} ${_fmt(card.face)}')
        .join('\n');
    await copyToClipboard(text);
    if (!mounted) return;
    setState(() => _counts.remove(face));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已提 ${cards.length} 张 \$${_fmt(face)} 卡，已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final groups = _groupByFace(provider.data);
    final totalCards =
        groups.values.fold<int>(0, (sum, cards) => sum + cards.length);
    final totalFace =
        groups.entries.fold<double>(0, (sum, e) => sum + e.key * e.value.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '快捷提卡',
          subtitle: '按面值分组，选择张数一键提卡，自动复制并标记已提。',
          child: groups.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('暂无库存卡', style: TextStyle(color: Colors.grey)),
                  ),
                )
              : Column(
                  children: [
                    ...groups.entries.map((entry) {
                      final face = entry.key;
                      final available = entry.value.length;
                      final count = (_counts[face] ?? 1).clamp(1, available);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.15),
                          ),
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.04),
                        ),
                        child: Row(
                          children: [
                            // Face value
                            Text(
                              '\$${_fmt(face)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '可用 $available 张',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const Spacer(),
                            // Count selector
                            IconButton.outlined(
                              icon: const Icon(Icons.remove, size: 16),
                              onPressed: count > 1
                                  ? () => setState(
                                      () => _counts[face] = count - 1)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              icon: const Icon(Icons.add, size: 16),
                              onPressed: count < available
                                  ? () => setState(
                                      () => _counts[face] = count + 1)
                                  : null,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 12),
                            // Pick button
                            FilledButton.icon(
                              onPressed: () => _pick(face, count),
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('提卡'),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Text(
                      '库存总览: $totalCards 张 / 面值 \$${_fmt(totalFace)}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
