import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/providers/app_provider.dart';

import 'test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final provider = AppProvider()
      ..data = buildSampleData()
      ..myRole = '星河'
      ..initialized = true
      ..syncStatus = '本地模式';

    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows bottom navigation on phone width', (tester) async {
    await pumpShell(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows navigation rail on desktop width', (tester) async {
    await pumpShell(tester, const Size(1280, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
