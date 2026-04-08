import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data.dart';
import '../services/clipboard_helper.dart';

class SettlePage extends StatefulWidget {
  const SettlePage({super.key});
  @override
  State<SettlePage> createState() => _SettlePageState();
}

class _SettlePageState extends State<SettlePage> {
  String? _expandedBatchId;

  String _fmtFace(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final batches = List.of(prov.data.batches)..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (batches.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('暂无批次', style: TextStyle(color: Colors.grey[500])),
          ))
        else
          ...batches.map((b) => _buildBatchCard(prov, b)),
      ],
    );
  }

  Widget _buildBatchCard(AppProvider prov, Batch batch) {
    final isExpanded = _expandedBatchId == batch.id;
    final soldCards = batch.cards.where((c) => c.sold && !c.bad).toList();
    final badCards = batch.cards.where((c) => c.bad).toList();
    final unsoldCards = batch.cards.where((c) => !c.sold && !c.bad).toList();
    final totalFace = batch.cards.fold<double>(0, (s, c) => s + c.face);
    final totalCost = totalFace * batch.rate;
    final soldFace = soldCards.fold<double>(0, (s, c) => s + c.face);
    final badRecovered = badCards.fold<double>(0, (s, c) => s + c.soldPrice);
    final badLoss = badCards.fold<double>(0, (s, c) => s + c.face) - badRecovered;
    final totalRevenue = soldFace + badRecovered;
    final persons = prov.data.persons;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedBatchId = isExpanded ? null : batch.id;
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${batch.batchDate} · 汇率${batch.rate} · ${batch.cards.length}张 · 已卖${soldCards.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('收入¥${_fmtFace(totalRevenue)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text('成本¥${_fmtFace(totalCost)}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
              ]),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  _row('总卡数', '${batch.cards.length} 张'),
                  _row('已卖 / 剩余 / 坏卡', '${soldCards.length} / ${unsoldCards.length} / ${badCards.length}'),
                  _row('总面值', '¥${_fmtFace(totalFace)}'),
                  _row('总成本 (面值×汇率)', '¥${_fmtFace(totalCost)}'),
                  _row('已售面值', '¥${_fmtFace(soldFace)}'),
                  if (badRecovered > 0) _row('坏卡回收余额', '¥${_fmtFace(badRecovered)}'),
                  if (badLoss > 0) _row('坏卡损失', '-¥${_fmtFace(badLoss)}', color: Colors.red),
                  _row('总收入', '¥${_fmtFace(totalRevenue)}', bold: true),
                  _row('利润', '¥${_fmtFace(totalRevenue - totalCost)}',
                    color: (totalRevenue - totalCost) >= 0 ? Colors.green : Colors.red, bold: true),

                  const Divider(height: 24),

                  // Per person summary
                  const Text('各人汇总', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),

                  ...persons.map((p) {
                    final pSoldCards = soldCards.where((c) => c.soldBy == p).toList();
                    final pFace = pSoldCards.fold<double>(0, (s, c) => s + c.face);
                    final pCount = pSoldCards.length;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8)),
                              child: Text(p, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            Text('$pCount张 · ¥${_fmtFace(pFace)}', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          ]),
                          if (pSoldCards.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            // Card list - selectable for copy
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...pSoldCards.map((c) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Row(children: [
                                      Expanded(child: Text(
                                        c.label,
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      )),
                                      Text('¥${_fmtFace(c.face)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () {
                                          final text = c.secret.isNotEmpty
                                              ? '${c.label} ${c.secret} ${_fmtFace(c.face)}'
                                              : '${c.label} ${_fmtFace(c.face)}';
                                          copyToClipboard(text);
                                          _msg('已复制: ${c.label}');
                                        },
                                        child: Icon(Icons.copy, size: 14, color: Colors.grey[400]),
                                      ),
                                    ]),
                                  )),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.copy, size: 14),
                                      label: Text('复制${p}全部卡号', style: const TextStyle(fontSize: 12)),
                                      onPressed: () {
                                        final text = pSoldCards.map((c) {
                                          final parts = [c.label];
                                          if (c.secret.isNotEmpty) parts.add(c.secret);
                                          parts.add(_fmtFace(c.face));
                                          return parts.join(' ');
                                        }).join('\n');
                                        copyToClipboard(text);
                                        _msg('已复制${p}的${pCount}张卡号');
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  if (badCards.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text('坏卡 (${badCards.length}张)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                    const SizedBox(height: 8),
                    ...badCards.map((c) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Expanded(child: SelectableText(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                        Text('面值¥${_fmtFace(c.face)}${c.soldPrice > 0 ? " 余额¥${_fmtFace(c.soldPrice)}" : ""}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ]),
                    )),
                  ],

                  const Divider(height: 24),

                  // Clear account button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_sweep, color: Colors.red),
                      label: const Text('清账（删除此批次）', style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('清账确认'),
                          content: Text('确定清账并删除批次"${batch.name}"的所有记录？此操作不可撤销。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定清账', style: TextStyle(color: Colors.red))),
                          ],
                        ));
                        if (ok == true) {
                          await prov.deleteBatch(batch.id);
                          setState(() => _expandedBatchId = null);
                          _msg('已清账: ${batch.name}');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: bold ? FontWeight.bold : null)),
        ],
      ),
    );
  }
}
