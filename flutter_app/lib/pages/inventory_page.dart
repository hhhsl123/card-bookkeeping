import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/data.dart';
import '../providers/app_provider.dart';
import '../services/clipboard_helper.dart';
import '../widgets/card_record_tile.dart';
import '../widgets/import_cards_dialog.dart';
import '../widgets/section_card.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  String _fmtFace(double value) => value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  Future<void> _showBadDialog(
    BuildContext context, {
    required String batchId,
    required CardItem card,
  }) async {
    final balanceController = TextEditingController(text: '0');
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('标记坏卡'),
        content: TextField(
          controller: balanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '实际余额',
            border: OutlineInputBorder(),
            hintText: '完全无效填 0',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, double.tryParse(balanceController.text) ?? 0),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await context.read<AppProvider>().markCardBad(batchId, card.id, actualBalance: result);
  }

  Future<void> _editRate(BuildContext context, Batch batch) async {
    final controller = TextEditingController(text: batch.rate.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改汇率'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '汇率', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, double.tryParse(controller.text)),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null || result <= 0 || !context.mounted) return;
    await context.read<AppProvider>().updateBatchRate(batch.id, result);
  }

  Future<void> _confirmArchiveCard(BuildContext context, String batchId, CardItem card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除卡片'),
        content: Text('确认从库存中移除 ${card.label}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().archiveCard(batchId, card.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final batches = provider.data.activeBatches;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '库存管理',
          subtitle: '库存页负责批次管理、坏卡处理、撤销和追加卡片。',
          actions: [
            FilledButton.icon(
              onPressed: () => showImportCardsDialog(context),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('从剪贴板加卡'),
            ),
          ],
          child: Text(
            batches.isEmpty ? '还没有可管理的批次' : '当前有 ${batches.length} 个进行中批次，点开批次后可直接处理卡片状态。',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        if (batches.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text('暂无批次', style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          ...batches.map(
            (batch) => Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: Text(batch.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Row(
                  children: [
                    Text('${batch.batchDate} · 汇率 '),
                    GestureDetector(
                      onTap: () => _editRate(context, batch),
                      child: Text(
                        batch.rate.toStringAsFixed(2),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(' · 库存 ${batch.availableCards.length} / 总 ${batch.totalCards}'),
                  ],
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TinyStat(label: '库存面值', value: _fmtFace(batch.availableFace)),
                            _TinyStat(label: '已提面值', value: _fmtFace(batch.pickedRevenue)),
                            _TinyStat(label: '坏卡余额', value: _fmtFace(batch.badRecovered)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => showImportCardsDialog(context, appendBatchId: batch.id),
                        icon: const Icon(Icons.playlist_add, size: 16),
                        label: const Text('追加卡'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 700;
                      final crossAxisCount = compact ? 1 : (constraints.maxWidth < 1100 ? 2 : 3);
                      final cards = batch.visibleCards;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: compact ? 2.4 : 1.55,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return CardRecordTile(
                            card: card,
                            costText: _fmtFace(card.face * batch.rate),
                            onCopy: () async {
                              final text = '${card.label}${card.secret.isNotEmpty ? ' ${card.secret}' : ''} ${_fmtFace(card.face)}';
                              await copyToClipboard(text);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制 ${card.label}')));
                              }
                            },
                            onBad: !card.isBad ? () => _showBadDialog(context, batchId: batch.id, card: card) : null,
                            onRestore: !card.isAvailable ? () => provider.restoreCard(batch.id, card.id) : null,
                            onArchive: () => _confirmArchiveCard(context, batch.id, card),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label $value'),
    );
  }
}
