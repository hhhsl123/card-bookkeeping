import '../models/data.dart';

class SettlementService {
  static SettlementOverview build(AppData data) {
    final activeBatches = data.activeBatches;
    final archivedBatches = data.clearedBatches;

    BatchSettlement summarizeBatch(Batch batch) {
      final revenue = batch.pickedRevenue + batch.badRecovered;
      final badFace = batch.badCards.fold<double>(0, (sum, card) => sum + card.face);
      final badLoss = badFace - batch.badRecovered;
      final visibleCost = batch.visibleCards.fold<double>(0, (sum, card) => sum + (card.face * batch.rate));
      return BatchSettlement(
        batch: batch,
        revenue: revenue,
        cost: visibleCost,
        profit: revenue - visibleCost,
        availableValue: batch.availableFace,
        badRecovered: batch.badRecovered,
        badLoss: badLoss,
      );
    }

    final batchSettlements = activeBatches.map(summarizeBatch).toList();
    final archivedSettlements = archivedBatches.map(summarizeBatch).toList();

    final personSettlements = data.persons.map((person) {
      final cards = <CardItem>[];
      var revenue = 0.0;
      var cost = 0.0;
      for (final batch in activeBatches) {
        for (final card in batch.pickedCards) {
          if (card.statusBy == person) {
            cards.add(card);
            revenue += card.face;
            cost += card.face * batch.rate;
          }
        }
      }
      return PersonSettlement(
        person: person,
        count: cards.length,
        revenue: revenue,
        cost: cost,
        profit: revenue - cost,
        cards: cards,
      );
    }).toList();

    final totalRevenue = batchSettlements.fold<double>(0, (sum, batch) => sum + batch.revenue);
    final totalCost = batchSettlements.fold<double>(0, (sum, batch) => sum + batch.cost);
    final badRecovered = batchSettlements.fold<double>(0, (sum, batch) => sum + batch.badRecovered);
    final badLoss = batchSettlements.fold<double>(0, (sum, batch) => sum + batch.badLoss);
    final availableValue = batchSettlements.fold<double>(0, (sum, batch) => sum + batch.availableValue);

    return SettlementOverview(
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      totalProfit: totalRevenue - totalCost,
      badRecovered: badRecovered,
      badLoss: badLoss,
      availableValue: availableValue,
      batches: batchSettlements,
      archivedBatches: archivedSettlements,
      persons: personSettlements,
    );
  }
}
