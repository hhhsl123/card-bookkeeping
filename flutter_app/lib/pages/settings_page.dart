import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../widgets/section_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _workspaceIdController;
  late final TextEditingController _workspaceNameController;
  late final TextEditingController _apiBaseController;
  late final TextEditingController _workspacePinController;
  late final TextEditingController _geminiApiKeyController;
  final TextEditingController _newPersonController = TextEditingController();
  final TextEditingController _newSourceController = TextEditingController();
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _workspaceIdController = TextEditingController();
    _workspaceNameController = TextEditingController();
    _apiBaseController = TextEditingController();
    _workspacePinController = TextEditingController();
    _geminiApiKeyController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final provider = context.read<AppProvider>();
    _workspaceIdController.text = provider.data.workspaceId;
    _workspaceNameController.text = provider.data.workspaceName;
    _apiBaseController.text = provider.config.apiBaseUrl;
    _workspacePinController.text = provider.config.workspacePin;
    _geminiApiKeyController.text = provider.config.geminiApiKey;
    _seeded = true;
  }

  @override
  void dispose() {
    _workspaceIdController.dispose();
    _workspaceNameController.dispose();
    _apiBaseController.dispose();
    _workspacePinController.dispose();
    _geminiApiKeyController.dispose();
    _newPersonController.dispose();
    _newSourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: '当前身份',
          subtitle: '提卡、坏卡和清账操作都会记录当前身份。',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: provider.data.persons
                .map(
                  (person) => ChoiceChip(
                    label: Text(person),
                    selected: provider.myRole == person,
                    onSelected: (_) => provider.setRole(person),
                  ),
                )
                .toList(),
          ),
        ),
        SectionCard(
          title: '成员管理',
          subtitle: '这里维护参与结算的人员列表。',
          child: Column(
            children: [
              ...provider.data.persons.map(
                (person) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(person),
                  trailing: IconButton(
                    onPressed: () => provider.removePerson(person),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newPersonController,
                      decoration: const InputDecoration(
                        hintText: '新增成员',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      await provider.addPerson(_newPersonController.text);
                      _newPersonController.clear();
                    },
                    child: const Text('添加'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: '卡片来源',
          subtitle: '配置加卡时可选的来源，批次名称会自动设为"来源+日期"。',
          child: Column(
            children: [
              ...provider.data.sources.map(
                (source) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(source),
                  trailing: IconButton(
                    onPressed: () => provider.removeSource(source),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSourceController,
                      decoration: const InputDecoration(
                        hintText: '新增来源',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      await provider.addSource(_newSourceController.text);
                      _newSourceController.clear();
                    },
                    child: const Text('添加'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Gemini AI',
          subtitle: '配置 API Key 后，导入卡片时自动用 AI 识别无法解析的内容。',
          child: Column(
            children: [
              TextField(
                controller: _geminiApiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key',
                  border: OutlineInputBorder(),
                  hintText: '从 aistudio.google.com 获取',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final provider = context.read<AppProvider>();
                    provider.config.geminiApiKey = _geminiApiKeyController.text.trim();
                    provider.saveGeminiKey(_geminiApiKeyController.text.trim());
                  },
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Cloudflare 连接',
          subtitle: '生产环境默认走 Pages + Worker；不填时应用保持本地模式。',
          child: Column(
            children: [
              TextField(
                controller: _workspaceIdController,
                decoration: const InputDecoration(labelText: 'Workspace ID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workspaceNameController,
                decoration: const InputDecoration(labelText: 'Workspace Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiBaseController,
                decoration: const InputDecoration(
                  labelText: 'Worker API Base URL',
                  border: OutlineInputBorder(),
                  hintText: '例如 https://card-bookkeeping-api.xxx.workers.dev',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _workspacePinController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Workspace PIN', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => provider.saveConnection(
                    apiBaseUrl: _apiBaseController.text,
                    workspacePin: _workspacePinController.text,
                    workspaceId: _workspaceIdController.text,
                    workspaceName: _workspaceNameController.text,
                  ),
                  icon: const Icon(Icons.cloud_done_outlined, size: 16),
                  label: const Text('保存并同步'),
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          title: '同步状态',
          subtitle: '本地改动会先立即生效，再防抖推送到 Worker。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前状态：${provider.syncStatus}'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: provider.syncing ? null : () => provider.syncNow(showMessage: true),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('推送本地'),
                  ),
                  OutlinedButton.icon(
                    onPressed: provider.syncing ? null : () => provider.refreshFromRemote(),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('从云端刷新'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
