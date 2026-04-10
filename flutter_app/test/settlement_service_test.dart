import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/settlement_service.dart';

import 'test_data.dart';

void main() {
  test('builds overview totals and per-person settlement', () {
    final overview = SettlementService.build(buildSampleData());

    expect(overview.totalRevenue, 15);
    expect(overview.totalCost, closeTo(430, 0.001));
    expect(overview.badRecovered, 5);
    expect(overview.availableValue, 85);

    final seller = overview.persons.firstWhere((person) => person.person == '星河');
    expect(seller.count, 1);
    expect(seller.revenue, 10);
    expect(seller.cost, 40);
  });
}
