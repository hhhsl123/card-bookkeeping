import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data.dart';
import '../services/clipboard_helper.dart';

class CheckPage extends StatefulWidget {
  const CheckPage({super.key});
  @override
  State<CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<CheckPage> {
  String? _expandedBatchId;
  final _targetCtrl = TextEditingController();
  List<CardItem>? _comboResult;
  String? _comboBatchId;

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  String _fmtFace(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  List<CardItem>? _findCombo(List<CardItem> cards, double target) {
    final sorted = List<CardItem>.from(cards)..sort((a, b) => b.face.compareTo(a.face));
    List<CardItem>? best;

    void bt(int start, double remaining, List<CardItem> chosen) {
      if ((remaining).abs() < 0.001) {
        if (best == null || chosen.length < best!.length) best = List.from(chosen);
        return;
      }
      if (remaining < -0.001 || (best != null && chosen.length >= best!.length) || start >= sorted.length) return;
      for (int i = start; i < sorted.length; i++) {
        if (sorted[i].face > remaining + 0.001) continue;
        chosen.add(sorted[i]);
        bt(i + 1, remaining - sorted[i].face, chosen);
        chosen.removeLast();
      }
    }

    bt(0, target, []);
    return best;
  }

  void _doCombo(Batch batch) {
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    if (target <= 0) { _msg('请输入目标金额'); return; }
    final unsold = batch.cards.where((c) => !c.sold && !c.bad).toList();
    final result = _findCombo(unsold, target);
    setState(() { _comboResult = result; _comboBatchId = batch.id; });
    if (result == null) _msg('无法凑出该金额');
  }

  Future<void> _pickCards(String batchId, List<CardItem> cards) async {
    final prov = context.read<AppProvider>();
    final fmt = (double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
    final text = cards.map((c) {
      final parts = [c.label];
      if (c.secret.isNotEmpty) parts.add(c.secret);
      parts.add(fmt(c.face));
      return parts.join(' ');
    }).join('\n');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('提卡确认 (${cards.length}张)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('将复制以下卡号卡密并标记为已卖\n卖出人: ${prov.myRole ?? "未知"}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认提卡')),
        ],
      ),
    );

    if (ok == true) {
      await copyToClipboard(text);
      await prov.pickCards(batchId, cards);
      setState(() => _comboResult = null);
      _msg('已复制并标记 ${cards.length} 张卡为已卖');
    }
  }

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
          ...activeBatches.map((b) => _buildBatchSection(b)),
          if (doneBatches.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('已卖完', style: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...doneBatches.map((b) => _buildBatchSection(b)),
          ],
        ],
      ],
    );
  }

  Widget _buildBatchSection(Batch batch) {
    final unsold = batch.cards.where((c) => !c.sold && !c.bad).toList();
    final badCards = batch.cards.where((c) => c.bad).toList();
    final isExpanded = _expandedBatchId == batch.id;
    final allDone = unsold.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedBatchId = isExpanded ? null : batch.id;
              if (!isExpanded) { _comboResult = null; _targetCtrl.clear(); }
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(batch.name, style: TextStyle(fontWeight: FontWeight.bold, color: allDone ? Colors.grey : null)),
                    const SizedBox(height: 2),
                    Text(
                      '${batch.batchDate} · 汇率${batch.rate} · 剩${unsold.length}张${badCards.isNotEmpty ? " · 坏${badCards.length}" : ""}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                )),
                if (!allDone) Text('¥${_fmtFace(unsold.fold<double>(0, (s, c) => s + c.face))}', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
              ]),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (unsold.isNotEmpty) ...[
                    // Combo
                    Row(children: [
                      Expanded(child: TextField(
                        controller: _targetCtrl,
                        decoration: const InputDecoration(hintText: '目标金额', border: OutlineInputBorder(), isDense: true),
                        keyboardType: TextInputType.number,
                      )),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => _doCombo(batch), child: const Text('组合')),
                    ]),

                    if (_comboResult != null && _comboBatchId == batch.id) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('${_comboResult!.length}张 = ¥${_fmtFace(_comboResult!.fold<double>(0, (s, c) => s + c.face))}',
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              FilledButton.icon(icon: const Icon(Icons.send, size: 16), label: const Text('提卡'),
                                onPressed: () => _pickCards(batch.id, _comboResult!)),
                            ]),
                            const SizedBox(height: 6),
                            ...(_comboResult!).map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('${c.label}${c.secret.isNotEmpty ? " ${c.secret}" : ""} (¥${_fmtFace(c.face)})',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                            )),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Unsold cards
                    ...unsold.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                            if (c.secret.isNotEmpty) Text(c.secret, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                          ],
                        )),
                        Text('¥${_fmtFace(c.face)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 2),
                        Text('成本¥${_fmtFace(c.face * batch.rate)}', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                        IconButton(
                          icon: const Icon(Icons.send, size: 16),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
                          tooltip: '提卡',
                          onPressed: () => _pickCards(batch.id, [c]),
                        ),
                      ]),
                    )),
                  ],

                  if (badCards.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('坏卡 (${badCards.length}张)', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                    ...badCards.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        Expanded(child: Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                        Text('面值¥${_fmtFace(c.face)}${c.soldPrice > 0 ? " 余额¥${_fmtFace(c.soldPrice)}" : ""}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ]),
                    )),
                  ],

                  if (unsold.isEmpty)
                    Center(child: Text('全部卖完', style: TextStyle(color: Colors.grey[400]))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
