import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/data.dart';
import '../providers/app_provider.dart';
import '../services/clipboard_helper.dart';
import '../widgets/import_cards_dialog.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.onNavigateToSettlement,
  });

  final VoidCallback onNavigateToSettlement;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Map<double, int> _counts = {};
  bool _adding = false;

  String _fmt(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

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

  Future<void> _addWithSource() async {
    final provider = context.read<AppProvider>();
    final clipText = await readClipboardText();
    if (!mounted) return;
    if (clipText == null || clipText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('剪贴板为空')));
      return;
    }

    final result = await showDialog<({String source, double rate})>(
      context: context,
      builder: (dialogContext) {
        final sources = List<String>.from(provider.data.sources);
        String? selectedSource = sources.isNotEmpty ? sources.first : null;
        final rateController = TextEditingController(text: '1');
        final newSourceController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('加卡'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sources.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: selectedSource,
                    decoration: const InputDecoration(labelText: '来源', border: OutlineInputBorder()),
                    items: sources
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedSource = v),
                  ),
                if (sources.isEmpty)
                  const Text('还没有来源，请先添加一个', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newSourceController,
                        decoration: const InputDecoration(
                          hintText: '新来源名称',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final name = newSourceController.text.trim();
                        if (name.isEmpty || sources.contains(name)) return;
                        provider.addSource(name);
                        newSourceController.clear();
                        setDialogState(() {
                          sources.add(name);
                          selectedSource = name;
                        });
                      },
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '汇率', border: OutlineInputBorder()),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
              FilledButton(
                onPressed: selectedSource == null
                    ? null
                    : () {
                        final rate = double.tryParse(rateController.text.trim()) ?? 1;
                        Navigator.pop(dialogContext, (source: selectedSource!, rate: rate));
                      },
                child: const Text('确认加卡'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() => _adding = true);
    final error = await provider.addWithSource(clipText, result.source, result.rate);
    if (!mounted) return;
    setState(() => _adding = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '已添加卡片（来源：${result.source}）')),
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
    final activeBatches = provider.data.activeBatches;
    final groups = _groupByFace(provider.data);
    final availableCards =
        groups.values.fold<int>(0, (sum, cards) => sum + cards.length);
    final pickedCards =
        activeBatches.fold<int>(0, (sum, batch) => sum + batch.pickedCards.length);
    final totalInventoryFace =
        groups.entries.fold<double>(0, (sum, e) => sum + e.key * e.value.length);

    final needsPin = !provider.hasRemoteConfigured;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (needsPin)
          Card(
            color: Colors.amber.shade50,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('请先在设置页设置 PIN 以启用数据同步')),
                ],
              ),
            ),
          ),
        // Add cards
        SectionCard(
          title: '加卡',
          subtitle: provider.myRole == null ? '先在设置里选择身份' : null,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _adding ? null : _addWithSource,
              icon: _adding
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_card_rounded, size: 16),
              label: const Text('加卡'),
            ),
          ),
        ),
        // Quick pick: cards grouped by face value
        if (groups.isNotEmpty)
          SectionCard(
            title: '快捷提卡',
            child: Column(
              children: groups.entries.map((entry) {
                final face = entry.key;
                final available = entry.value.length;
                final count = (_counts[face] ?? 1).clamp(1, available);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    ),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.04),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '\$${_fmt(face)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      Text('余$available', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      const Spacer(),
                      IconButton.outlined(
                        icon: const Icon(Icons.remove, size: 14),
                        onPressed: count > 1
                            ? () => setState(() => _counts[face] = count - 1)
                            : null,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        iconSize: 14,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '$count',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton.outlined(
                        icon: const Icon(Icons.add, size: 14),
                        onPressed: count < available
                            ? () => setState(() => _counts[face] = count + 1)
                            : null,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        iconSize: 14,
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _pick(face, count),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('提卡'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        // Inventory overview
        if (availableCards > 0 || pickedCards > 0)
          SectionCard(
            title: '库存概览',
            child: Row(
              children: [
                MetricCard(label: '可提', value: '$availableCards', color: Colors.teal),
                const SizedBox(width: 12),
                MetricCard(label: '已提', value: '$pickedCards', color: Colors.green),
                const SizedBox(width: 12),
                MetricCard(label: '库存面值', value: _fmt(totalInventoryFace), color: Colors.orange),
              ].map((child) => child is SizedBox ? child : Expanded(child: child)).toList(),
            ),
          ),
        // Recent activity
        SectionCard(
          title: '最近活动',
          actions: [
            OutlinedButton.icon(
              onPressed: widget.onNavigateToSettlement,
              icon: const Icon(Icons.calculate_rounded, size: 16),
              label: const Text('算账'),
            ),
          ],
          child: provider.data.recentActivities.isEmpty
              ? Text('还没有活动记录', style: TextStyle(color: Colors.grey.shade600))
              : Column(
                  children: provider.data.recentActivities.take(6).map((activity) {
                    final time = DateTime.fromMillisecondsSinceEpoch(activity.createdAt);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        child: Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                      ),
                      title: Text(activity.summary),
                      subtitle: Text('${activity.actor} · ${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}'),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
