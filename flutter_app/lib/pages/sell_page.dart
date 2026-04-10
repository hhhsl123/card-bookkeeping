import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data.dart';
import '../widgets/card_tile.dart';
import '../services/clipboard_helper.dart';

class SellPage extends StatefulWidget {
  const SellPage({super.key});
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  String? _expandedBatchId;
  final Set<String> _selected = {};

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final batches = prov.data.batches;

    final activeBatches = batches.where((b) => b.cards.any((c) => !c.sold && !c.bad)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final doneBatches = batches.where((b) => b.cards.isNotEmpty && !b.cards.any((c) => !c.sold && !c.bad)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (activeBatches.isEmpty && doneBatches.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('暂无批次', style: TextStyle(color: Colors.grey[500])),
          ))
        else ...[
          ...activeBatches.map((b) => _buildBatchCard(prov, b)),
          if (doneBatches.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('已卖完', style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...doneBatches.map((b) => _buildBatchCard(prov, b)),
          ],
        ],
      ],
    );
  }

  Widget _buildBatchCard(AppProvider prov, Batch batch) {
    final isExpanded = _expandedBatchId == batch.id;
    final unsold = batch.cards.where((c) => !c.sold && !c.bad).length;
    final allDone = unsold == 0;

    final hasUnsoldSelected = _selected.isNotEmpty && isExpanded &&
        batch.cards.any((c) => _selected.contains(c.id) && !c.sold && !c.bad);
    final hasSoldSelected = _selected.isNotEmpty && isExpanded &&
        batch.cards.any((c) => _selected.contains(c.id) && (c.sold || c.bad));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedBatchId = null;
              } else {
                _expandedBatchId = batch.id;
              }
              _selected.clear();
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.name, style: TextStyle(fontWeight: FontWeight.bold, color: allDone ? Colors.grey : null)),
                    Text('${batch.batchDate} · 剩${unsold}张 / 共${batch.cards.length}张',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                )),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
              ]),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, childAspectRatio: 0.85, crossAxisSpacing: 6, mainAxisSpacing: 6,
                    ),
                    itemCount: batch.cards.length,
                    itemBuilder: (_, i) {
                      final c = batch.cards[i];
                      return CardTile(
                        card: c,
                        selected: _selected.contains(c.id),
                        onTap: () {
                          setState(() {
                            if (_selected.contains(c.id)) {
                              _selected.remove(c.id);
                            } else {
                              _selected.add(c.id);
                            }
                          });
                        },
                        onCopy: () async {
                          final text = c.secret.isNotEmpty ? '${c.label} ${c.secret}' : c.label;
                          await copyToClipboard(text);
                          if (mounted) _msg('已复制: ${c.label}');
                        },
                      );
                    },
                  ),

                  if (_selected.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Text('已选 ${_selected.length} 张卡', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (hasUnsoldSelected)
                                FilledButton.icon(
                                  icon: const Icon(Icons.check),
                                  label: const Text('确认卖出'),
                                  onPressed: () async {
                                    final unsoldIds = batch.cards
                                        .where((c) => _selected.contains(c.id) && !c.sold && !c.bad)
                                        .map((c) => c.id)
                                        .toSet();
                                    if (unsoldIds.isEmpty) return;
                                    final seller = prov.myRole ?? '未知';
                                    await prov.sellCards(batch.id, unsoldIds, seller);
                                    _msg('已标记 ${unsoldIds.length} 张卡为已卖');
                                    setState(() => _selected.clear());
                                  },
                                ),
                              FilledButton.icon(
                                icon: const Icon(Icons.warning),
                                label: const Text('标记坏卡'),
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () async {
                                  final balanceCtrl = TextEditingController(text: '0');
                                  final result = await showDialog<double?>(context: context, builder: (ctx) => AlertDialog(
                                    title: const Text('标记坏卡'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('确定将 ${_selected.length} 张卡标记为坏卡？'),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: balanceCtrl,
                                          decoration: const InputDecoration(
                                            labelText: '实际余额（每张）',
                                            hintText: '0 = 完全无效，如面值20实际5则填5',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('取消')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, double.tryParse(balanceCtrl.text) ?? 0), child: const Text('确定', style: TextStyle(color: Colors.red))),
                                    ],
                                  ));
                                  if (result != null) {
                                    await prov.markBad(batch.id, _selected, actualBalance: result);
                                    _msg('已标记 ${_selected.length} 张坏卡${result > 0 ? "（余额$result）" : ""}');
                                    setState(() => _selected.clear());
                                  }
                                },
                              ),
                              if (hasSoldSelected)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.undo),
                                  label: const Text('撤销'),
                                  onPressed: () async {
                                    await prov.undoCards(batch.id, _selected);
                                    _msg('已撤销 ${_selected.length} 张卡');
                                    setState(() => _selected.clear());
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
