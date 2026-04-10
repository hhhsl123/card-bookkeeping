import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/data.dart';
import '../providers/app_provider.dart';
import '../services/clipboard_helper.dart';
import '../services/settlement_service.dart';
import '../widgets/metric_card.dart';
import '../widgets/section_card.dart';

class SettlePage extends StatelessWidget {
  const SettlePage({super.key});

  String _fmt(double value) => value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  String _batchSummary(BatchSettlement settlement) {
    return [
      settlement.batch.name,
      '批次日期 ${settlement.batch.batchDate}',
      '收入 ${_fmt(settlement.revenue)}',
      '成本 ${_fmt(settlement.cost)}',
      '利润 ${_fmt(settlement.profit)}',
      '库存面值 ${_fmt(settlement.availableValue)}',
      if (settlement.badRecovered > 0) '坏卡回收 ${_fmt(settlement.badRecovered)}',
      if (settlement.badLoss > 0) '坏卡损失 ${_fmt(settlement.badLoss)}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final overview = SettlementService.build(provider.data);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '总览',
          subtitle: '算账页只统计未清账批次，已清账批次会单独归档。',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final cards = [
                MetricCard(label: '总收入', value: _fmt(overview.totalRevenue), color: Colors.green),
                MetricCard(label: '总成本', value: _fmt(overview.totalCost), color: Colors.blue),
                MetricCard(label: '总利润', value: _fmt(overview.totalProfit), color: overview.totalProfit >= 0 ? Colors.teal : Colors.red),
                MetricCard(label: '库存价值', value: _fmt(overview.availableValue), color: Colors.orange),
                MetricCard(label: '坏卡回收', value: _fmt(overview.badRecovered), color: Colors.deepOrange),
                MetricCard(label: '坏卡损失', value: _fmt(overview.badLoss), color: Colors.red),
              ];
              if (compact) {
                return Column(
                  children: cards
                      .map((card) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card,
                          ))
                      .toList(),
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards.map((card) => SizedBox(width: (constraints.maxWidth - 24) / 3, child: card)).toList(),
              );
            },
          ),
        ),
        SectionCard(
          title: '按批次',
          subtitle: '这里看每个批次的利润、坏卡和清账动作。',
          child: overview.batches.isEmpty
              ? Text('没有可结算的批次', style: TextStyle(color: Colors.grey.shade600))
              : Column(
                  children: overview.batches.map((settlement) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        title: Text(settlement.batch.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${settlement.batch.batchDate} · 收入 ${_fmt(settlement.revenue)} · 利润 ${_fmt(settlement.profit)}',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _Tag(label: '库存 ${settlement.batch.availableCards.length}'),
                              _Tag(label: '已提 ${settlement.batch.pickedCards.length}'),
                              _Tag(label: '坏卡 ${settlement.batch.badCards.length}'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _Row(label: '收入', value: _fmt(settlement.revenue)),
                          _Row(label: '成本', value: _fmt(settlement.cost)),
                          _Row(label: '利润', value: _fmt(settlement.profit)),
                          _Row(label: '库存面值', value: _fmt(settlement.availableValue)),
                          _Row(label: '坏卡回收', value: _fmt(settlement.badRecovered)),
                          _Row(label: '坏卡损失', value: _fmt(settlement.badLoss)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => copyToClipboard(_batchSummary(settlement)),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('复制摘要'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('清账批次'),
                                      content: Text('确认清账 ${settlement.batch.name}？清账后会从当前总账中移出。'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
                                        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('确认清账')),
                                      ],
                                    ),
                                  );
                                  if (ok == true && context.mounted) {
                                    await context.read<AppProvider>().clearBatch(settlement.batch.id);
                                  }
                                },
                                icon: const Icon(Icons.archive_outlined, size: 16),
                                label: const Text('清账归档'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        SectionCard(
          title: '按人员',
          subtitle: '按人核对卖出张数、销售额、成本和利润。',
          child: overview.persons.isEmpty
              ? Text('还没有人员结算数据', style: TextStyle(color: Colors.grey.shade600))
              : Column(
                  children: overview.persons.map((person) {
                    final summary = [
                      person.person,
                      '张数 ${person.count}',
                      '销售额 ${_fmt(person.revenue)}',
                      '成本 ${_fmt(person.cost)}',
                      '利润 ${_fmt(person.profit)}',
                      if (person.cards.isNotEmpty)
                        ...person.cards.map((card) => '${card.label}${card.secret.isNotEmpty ? ' ${card.secret}' : ''} ${_fmt(card.face)}'),
                    ].join('\n');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(person.person, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => copyToClipboard(summary),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('复制明细'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _Row(label: '卖出张数', value: '${person.count}'),
                          _Row(label: '销售额', value: _fmt(person.revenue)),
                          _Row(label: '成本', value: _fmt(person.cost)),
                          _Row(label: '利润', value: _fmt(person.profit)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        if (overview.archivedBatches.isNotEmpty)
          SectionCard(
            title: '已清账批次',
            subtitle: '归档后的批次会保留在本地和云端，但不再参与当前总账。',
            child: Column(
              children: overview.archivedBatches
                  .map(
                    (settlement) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(settlement.batch.name),
                      subtitle: Text('${settlement.batch.batchDate} · 已清账'),
                      trailing: Text('利润 ${_fmt(settlement.profit)}'),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
