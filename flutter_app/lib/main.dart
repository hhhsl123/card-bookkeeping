import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/dashboard_page.dart';
import 'pages/inventory_page.dart';
import 'pages/pick_page.dart';
import 'pages/settle_page.dart';
import 'pages/settings_page.dart';
import 'providers/app_provider.dart';

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
      title: 'Card Bookkeeping',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0C7D69),
        scaffoldBackgroundColor: const Color(0xFFF5F4EF),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
          ),
        ),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final List<String> _titles = const <String>['首页', '库存', '提卡', '算账', '设置'];

  late final VoidCallback _providerListener;
  AppProvider? _provider;

  @override
  void initState() {
    super.initState();
    _providerListener = () {
      final provider = context.read<AppProvider>();
      final message = provider.syncMessage;
      if (message != null && mounted) {
        provider.clearSyncMessage();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<AppProvider>();
      _provider?.addListener(_providerListener);
      _maybeAskRole();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_providerListener);
    super.dispose();
  }

  void _maybeAskRole() {
    final provider = context.read<AppProvider>();
    if ((provider.myRole ?? '').isEmpty && provider.data.persons.isNotEmpty) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('选择身份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: provider.data.persons
                .map(
                  (person) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          await provider.setRole(person);
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                        },
                        child: Text('我是 $person'),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final pages = <Widget>[
      DashboardPage(
        onNavigateToSettlement: () => setState(() => _index = 3),
      ),
      const InventoryPage(),
      const PickPage(),
      const SettlePage(),
      const SettingsPage(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 900;
        final scaffoldBody = IndexedStack(index: _index, children: pages);

        return Scaffold(
          appBar: AppBar(
            title: Text('${_titles[_index]}${provider.myRole != null ? ' · ${provider.myRole}' : ''}'),
            actions: const [],
          ),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (value) => setState(() => _index = value),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('首页')),
                        NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('库存')),
                        NavigationRailDestination(icon: Icon(Icons.flash_on_outlined), selectedIcon: Icon(Icons.flash_on), label: Text('提卡')),
                        NavigationRailDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: Text('算账')),
                        NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('设置')),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: scaffoldBody),
                  ],
                )
              : scaffoldBody,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (value) => setState(() => _index = value),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '首页'),
                    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: '库存'),
                    NavigationDestination(icon: Icon(Icons.flash_on_outlined), selectedIcon: Icon(Icons.flash_on), label: '提卡'),
                    NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: '算账'),
                    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
                  ],
                ),
        );
      },
    );
  }
}
