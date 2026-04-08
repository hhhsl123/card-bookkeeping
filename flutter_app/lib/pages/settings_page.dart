import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/storage.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current role
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前身份', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text(prov.myRole ?? '未选择', style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('切换身份：', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: prov.data.persons.map((p) => ChoiceChip(
                    label: Text(p),
                    selected: prov.myRole == p,
                    onSelected: (_) => prov.setRole(p),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Person management
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('人员管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                ...prov.data.persons.map((p) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('删除人员？'),
                          content: Text('确定删除 $p？'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (ok == true) prov.removePerson(p);
                    },
                  ),
                )),
                const SizedBox(height: 8),
                _AddPersonButton(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Sync info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('数据同步', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Text('状态: ${prov.syncStatus}', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.sync),
                    label: const Text('手动同步'),
                    onPressed: prov.syncing ? null : () => prov.pullFromCloud(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPersonButton extends StatefulWidget {
  @override
  State<_AddPersonButton> createState() => _AddPersonButtonState();
}

class _AddPersonButtonState extends State<_AddPersonButton> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: TextField(
          controller: _ctrl,
          decoration: const InputDecoration(hintText: '新人员名称', border: OutlineInputBorder(), isDense: true),
        )),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            final name = _ctrl.text.trim();
            if (name.isEmpty) return;
            context.read<AppProvider>().addPerson(name);
            _ctrl.clear();
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
