import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'pages/batch_page.dart';
import 'pages/sell_page.dart';
import 'pages/check_page.dart';
import 'pages/settle_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '双人卡片记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4a6cf7),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final _pages = const [
    BatchPage(),
    SellPage(),
    CheckPage(),
    SettlePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRole();
      _listenSync();
    });
  }

  void _listenSync() {
    final prov = context.read<AppProvider>();
    prov.addListener(() {
      final msg = prov.syncMessage;
      if (msg != null && mounted) {
        prov.clearSyncMessage();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: msg.contains('成功') ? Colors.green : Colors.red,
        ));
      }
    });
  }

  void _checkRole() {
    final prov = context.read<AppProvider>();
    if (prov.myRole == null || prov.myRole!.isEmpty) {
      _showRolePicker();
    }
  }

  void _showRolePicker() {
    final prov = context.read<AppProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('你是谁？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('首次使用，请选择你的身份'),
            const SizedBox(height: 16),
            ...prov.data.persons.map((name) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    prov.setRole(name);
                    Navigator.pop(ctx);
                  },
                  child: Text('我是 $name'),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text('💳 记账 ${prov.myRole != null ? "(${prov.myRole})" : ""}'),
        centerTitle: true,
        actions: [
          if (prov.syncStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(prov.syncStatus, style: TextStyle(fontSize: 11, color: prov.syncStatus == '同步失败' ? Colors.red : Colors.grey[500])),
            ),
          if (prov.syncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: '同步',
              onPressed: () => prov.pullFromCloud(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppProvider>().pullFromCloud(),
        child: _pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.sell), label: '卖卡'),
          NavigationDestination(icon: Icon(Icons.search), label: '查卡'),
          NavigationDestination(icon: Icon(Icons.calculate), label: '结算'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
