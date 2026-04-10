import '../models/data.dart';

class CardPicker {
  static List<CardItem>? exactPick(List<CardItem> cards, double target) {
    if (target <= 0) return null;
    final sorted = List<CardItem>.from(cards.where((card) => card.isAvailable))
      ..sort((left, right) => right.face.compareTo(left.face));

    List<CardItem>? best;

    void search(int start, double remaining, List<CardItem> chosen) {
      if (remaining.abs() < 0.001) {
        if (best == null || chosen.length < best!.length) {
          best = List<CardItem>.from(chosen);
        }
        return;
      }
      if (remaining < -0.001) return;
      if (best != null && chosen.length >= best!.length) return;
      if (start >= sorted.length) return;

      for (var index = start; index < sorted.length; index += 1) {
        final card = sorted[index];
        if (card.face > remaining + 0.001) continue;
        chosen.add(card);
        search(index + 1, remaining - card.face, chosen);
        chosen.removeLast();
      }
    }

    search(0, target, <CardItem>[]);
    return best;
  }
}
