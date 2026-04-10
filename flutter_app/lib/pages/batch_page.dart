import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data.dart';

class BatchPage extends StatefulWidget {
  const BatchPage({super.key});
  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  final _nameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _faceCtrl = TextEditingController();
  final _cardsCtrl = TextEditingController();
  String? _expandedBatchId;

  static int _counter = 0;
  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
  }

  String _genId() {
    _counter++;
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${_counter.toRadixString(36)}_${_rng.nextInt(0xFFFF).toRadixString(36)}';
  }

  Future<void> _createBatch() async {
    final name = _nameCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    final date = _dateCtrl.text.trim();
    final globalFace = double.tryParse(_faceCtrl.text) ?? 0;
    final raw = _cardsCtrl.text.trim();

    if (name.isEmpty) { _msg('请输入批次名称'); return; }
    if (rate <= 0) { _msg('请输入进货汇率'); return; }
    if (raw.isEmpty) { _msg('请添加卡片'); return; }

    final prov = context.read<AppProvider>();

    // Check for duplicate batch name
    final existingNames = prov.data.batches.map((b) => b.name).toSet();
    if (existingNames.contains(name)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('批次名称重复'),
          content: Text('已存在名为"$name"的批次，确定继续创建吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续创建')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final cards = <CardItem>[];
    for (final line in raw.split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final parts = l.split(RegExp(r'\s+'));
      String label = '', secret = '';
      double face = globalFace;

      if (globalFace > 0) {
        label = parts[0];
        if (parts.length >= 2) secret = parts.sublist(1).join(' ');
      } else {
        if (parts.length >= 3 && double.tryParse(parts.last) != null) {
          face = double.tryParse(parts.last) ?? 0;
          secret = parts[parts.length - 2];
          label = parts.sublist(0, parts.length - 2).join(' ');
        } else if (parts.length == 2 && double.tryParse(parts[1]) != null) {
          label = parts[0];
          face = double.tryParse(parts[1]) ?? 0;
        } else {
          label = parts.join(' ');
        }
      }

      cards.add(CardItem(id: _genId(), label: label, secret: secret, face: face));
    }

    if (cards.isEmpty) { _msg('未解析到有效卡片'); return; }

    // Check for internal duplicates
    final seenLabels = <String>{};
    final internalDups = <String>[];
    for (final c in cards) {
      if (!seenLabels.add(c.label)) internalDups.add(c.label);
    }

    if (internalDups.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('批次内有重复卡号'),
          content: Text('以下卡号重复：\n${internalDups.take(10).join('\n')}${internalDups.length > 10 ? '\n...' : ''}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续添加')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // Check for cross-batch duplicates
    final existingLabels = <String, String>{};
    for (final b in prov.data.batches) {
      for (final c in b.cards) {
        existingLabels[c.label] = b.name;
      }
    }
    final crossDups = cards.where((c) => existingLabels.containsKey(c.label)).toList();

    if (crossDups.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('发现重复卡号'),
          content: SingleChildScrollView(
            child: Text(
              '以下 ${crossDups.length} 张卡在其他批次已存在：\n${crossDups.take(10).map((c) => '${c.label} → ${existingLabels[c.label]}').join('\n')}${crossDups.length > 10 ? '\n...' : ''}',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续添加')),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final totalFace = cards.fold<double>(0, (s, c) => s + c.face);
    final batch = Batch(
      id: _genId(),
      name: name,
      rate: rate,
      batchDate: date,
      cost: totalFace * rate,
      cards: cards,
    );

    prov.addBatch(batch);
    _nameCtrl.clear();
    _rateCtrl.clear();
    _faceCtrl.clear();
    _cardsCtrl.clear();
    _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
    _msg('创建成功，${cards.length} 张卡');
  }

  void _confirmDeleteCard(AppProvider prov, Batch b, CardItem c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除卡片？'),
        content: Text('确定删除卡片 ${c.label}？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              prov.deleteCard(b.id, c.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    final activeBatches = prov.data.batches.where((b) {
      return b.cards.any((c) => !c.sold && !c.bad);
    }).toList().reversed.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('新建批次', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '批次名称', border: OutlineInputBorder(), isDense: true))),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<double>(
                    value: double.tryParse(_rateCtrl.text),
                    decoration: const InputDecoration(labelText: '进货汇率', border: OutlineInputBorder(), isDense: true),
                    items: [
                      for (double v = 3.0; v <= 5.001; v += 0.05)
                        DropdownMenuItem(value: double.parse(v.toStringAsFixed(2)), child: Text(v.toStringAsFixed(2))),
                    ],
                    onChanged: (v) => setState(() { _rateCtrl.text = v?.toStringAsFixed(2) ?? ''; }),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(controller: _faceCtrl, decoration: const InputDecoration(labelText: '统一面值（选填）', border: OutlineInputBorder(), isDense: true, hintText: '留空则从每行解析'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 12),
                TextField(controller: _cardsCtrl, decoration: const InputDecoration(labelText: '卡片（每行一张）', border: OutlineInputBorder(), isDense: true, hintText: '卡号 卡密 面值\n或 卡号 面值'), maxLines: 6),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _createBatch, child: const Text('创建批次'))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (activeBatches.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('暂无进行中的批次', style: TextStyle(color: Colors.grey[500])),
          ))
        else ...[
          Text('当前批次 (${activeBatches.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...activeBatches.map((b) => _buildBatchCard(prov, b)),
        ],
      ],
    );
  }

  Widget _buildBatchCard(AppProvider prov, Batch b) {
    final total = b.cards.length;
    final sold = b.cards.where((c) => c.sold && !c.bad).length;
    final bad = b.cards.where((c) => c.bad).length;
    final remain = total - sold - bad;
    final pct = total > 0 ? sold / total : 0.0;
    final isExpanded = _expandedBatchId == b.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expandedBatchId = isExpanded ? null : b.id;
            }),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        showDialog(context: context, builder: (ctx) => AlertDialog(
                          title: const Text('删除批次？'),
                          content: Text('确定删除 ${b.name}？'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                            TextButton(onPressed: () { prov.deleteBatch(b.id); Navigator.pop(ctx); }, child: const Text('删除', style: TextStyle(color: Colors.red))),
                          ],
                        ));
                      },
                    ),
                  ]),
                  Text('📅 ${b.batchDate}  💱 ${b.rate}  📦 ${total}张', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: pct, minHeight: 5, borderRadius: BorderRadius.circular(3)),
                  const SizedBox(height: 4),
                  Text('已卖$sold  剩$remain${bad > 0 ? "  坏$bad" : ""}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: b.cards.length,
                itemBuilder: (_, i) {
                  final c = b.cards[i];
                  final statusColor = c.bad ? Colors.red : (c.sold ? Colors.green : Colors.grey);
                  final statusText = c.bad ? '坏卡' : (c.sold ? '已卖(${c.soldBy ?? ""})' : '未卖');
                  return ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -4),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(statusText, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w500)),
                    ),
                    title: Text(c.label, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    subtitle: c.secret.isNotEmpty ? Text(c.secret, style: const TextStyle(fontSize: 10, color: Colors.grey)) : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('¥${c.face % 1 == 0 ? c.face.toInt() : c.face}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Colors.red),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                          tooltip: '删除',
                          onPressed: () => _confirmDeleteCard(prov, b, c),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
