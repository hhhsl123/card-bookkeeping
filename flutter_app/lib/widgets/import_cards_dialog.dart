import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/data.dart';
import '../providers/app_provider.dart';
import '../services/clipboard_helper.dart';

Future<void> showImportCardsDialog(
  BuildContext context, {
  String? appendBatchId,
}) async {
  final clipboardText = (await readClipboardText())?.trim();
  if (!context.mounted) return;

  final seedText = clipboardText?.isNotEmpty == true
      ? clipboardText!
      : await showDialog<String>(
          context: context,
          builder: (dialogContext) {
            final controller = TextEditingController();
            return AlertDialog(
              title: const Text('剪贴板为空'),
              content: TextField(
                controller: controller,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText: '把卡号内容粘贴到这里',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, controller.text),
                  child: const Text('继续'),
                ),
              ],
            );
          },
        );

  if (!context.mounted || seedText == null || seedText.trim().isEmpty) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ImportCardsDialog(
      initialRaw: seedText,
      appendBatchId: appendBatchId,
    ),
  );
}

class ImportCardsDialog extends StatefulWidget {
  const ImportCardsDialog({
    super.key,
    required this.initialRaw,
    this.appendBatchId,
  });

  final String initialRaw;
  final String? appendBatchId;

  @override
  State<ImportCardsDialog> createState() => _ImportCardsDialogState();
}

class _ImportCardsDialogState extends State<ImportCardsDialog> {
  late final TextEditingController _rawController;
  late final TextEditingController _nameController;
  late final TextEditingController _rateController;
  late final TextEditingController _dateController;
  late final TextEditingController _faceController;
  late bool _appendMode;
  String? _selectedBatchId;
  ImportPreview? _preview;
  bool _submitting = false;
  bool _aiParsing = false;
  bool _seededBatchFields = false;

  @override
  void initState() {
    super.initState();
    _appendMode = widget.appendBatchId != null;
    _selectedBatchId = widget.appendBatchId;
    _rawController = TextEditingController(text: widget.initialRaw);
    _nameController = TextEditingController();
    _rateController = TextEditingController(text: '4.00');
    _dateController = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    _faceController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seededBatchFields && _selectedBatchId != null) {
      final provider = context.read<AppProvider>();
      Batch? selectedBatch;
      for (final batch in provider.data.activeBatches) {
        if (batch.id == _selectedBatchId) {
          selectedBatch = batch;
          break;
        }
      }
      if (selectedBatch != null) {
        _nameController.text = selectedBatch.name;
        _rateController.text = selectedBatch.rate.toStringAsFixed(2);
        _dateController.text = selectedBatch.batchDate;
        _seededBatchFields = true;
      }
    }
    _refreshPreview();
  }

  @override
  void dispose() {
    _rawController.dispose();
    _nameController.dispose();
    _rateController.dispose();
    _dateController.dispose();
    _faceController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    final provider = context.read<AppProvider>();
    final faceOverride = double.tryParse(_faceController.text.trim());
    final localPreview = provider.buildImportPreview(
      _rawController.text,
      unifiedFace: faceOverride,
    );
    setState(() => _preview = localPreview);

    // Auto fallback to Gemini if there are issues and API key is configured
    if (localPreview.issues.isNotEmpty && provider.config.hasGeminiConfigured) {
      setState(() => _aiParsing = true);
      provider
          .buildImportPreviewWithAI(_rawController.text, unifiedFace: faceOverride)
          .then((aiPreview) {
        if (mounted) setState(() { _preview = aiPreview; _aiParsing = false; });
      }).catchError((_) {
        if (mounted) setState(() => _aiParsing = false);
      });
    }
  }

  Future<void> _submit() async {
    final preview = _preview;
    if (preview == null || !preview.hasValidCards) return;
    final provider = context.read<AppProvider>();

    final batchName = _nameController.text.trim();
    final batchRate = double.tryParse(_rateController.text.trim()) ?? 0;
    final batchDate = _dateController.text.trim();

    if (!_appendMode && batchName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入批次名称')));
      return;
    }
    if (!_appendMode && batchRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效汇率')));
      return;
    }
    if (_appendMode && _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择要追加的批次')));
      return;
    }

    setState(() => _submitting = true);
    if (_appendMode) {
      await provider.appendCardsToBatch(batchId: _selectedBatchId!, preview: preview);
    } else {
      await provider.createBatchFromPreview(
        name: batchName,
        rate: batchRate,
        batchDate: batchDate,
        preview: preview,
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final preview = _preview;
    final activeBatches = provider.data.activeBatches;
    return AlertDialog(
      title: Text(widget.appendBatchId == null ? '从剪贴板加卡' : '追加卡片'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.appendBatchId == null)
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('新建批次'),
                      selected: !_appendMode,
                      onSelected: (_) => setState(() => _appendMode = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('追加到已有批次'),
                      selected: _appendMode,
                      onSelected: activeBatches.isEmpty ? null : (_) => setState(() => _appendMode = true),
                    ),
                  ],
                ),
              if (_appendMode) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedBatchId,
                  decoration: const InputDecoration(
                    labelText: '目标批次',
                    border: OutlineInputBorder(),
                  ),
                  items: activeBatches
                      .map((batch) => DropdownMenuItem<String>(value: batch.id, child: Text(batch.name)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBatchId = value;
                    });
                    Batch? selectedBatch;
                    for (final batch in activeBatches) {
                      if (batch.id == value) {
                        selectedBatch = batch;
                        break;
                      }
                    }
                    if (selectedBatch != null) {
                      _nameController.text = selectedBatch.name;
                      _rateController.text = selectedBatch.rate.toStringAsFixed(2);
                      _dateController.text = selectedBatch.batchDate;
                    }
                  },
                ),
              ] else ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '批次名称', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '汇率', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(labelText: '日期', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _faceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '统一面值（选填）',
                  border: OutlineInputBorder(),
                  hintText: '不填则按每行最后一列解析',
                ),
                onChanged: (_) => _refreshPreview(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rawController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: '卡片内容',
                  border: OutlineInputBorder(),
                  hintText: '每行一张：卡号 卡密 面值 或 卡号 面值',
                ),
                onChanged: (_) => _refreshPreview(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _refreshPreview,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('刷新预览'),
                  ),
                  const SizedBox(width: 12),
                  if (_aiParsing)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('AI 识别中...'),
                      ],
                    )
                  else if (preview != null)
                    Text(
                      '有效 ${preview.cards.length} · 跳过 ${preview.skippedCount}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                ],
              ),
              if (preview != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('导入预览', style: Theme.of(context).textTheme.titleSmall),
                      if (preview.cards.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...preview.cards.take(6).map(
                              (card) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('${card.label}${card.secret.isNotEmpty ? ' ${card.secret}' : ''} ${card.face}'),
                              ),
                            ),
                        if (preview.cards.length > 6)
                          Text('还有 ${preview.cards.length - 6} 张卡未展开', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                      if (preview.duplicateExisting.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '已跳过重复卡：${preview.duplicateExisting.entries.take(4).map((item) => '${item.key}(${item.value})').join('、')}',
                          style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                        ),
                      ],
                      if (preview.duplicateWithinInput.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '批次内重复：${preview.duplicateWithinInput.take(4).join('、')}',
                          style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                        ),
                      ],
                      if (preview.issues.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...preview.issues.take(4).map(
                              (issue) => Text(
                                issue.message,
                                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting || preview == null || !preview.hasValidCards ? null : _submit,
          child: Text(_submitting ? '提交中...' : (_appendMode ? '追加导入' : '创建批次')),
        ),
      ],
    );
  }
}
