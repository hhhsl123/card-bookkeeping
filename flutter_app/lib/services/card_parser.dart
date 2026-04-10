import '../models/data.dart';
import 'gemini_service.dart';

class CardParser {
  /// Parse with AI fallback: first try local parser, then send failed lines to Gemini.
  static Future<ImportPreview> previewWithAI({
    required String raw,
    required Map<String, String> existingLabels,
    required String geminiApiKey,
    double? unifiedFace,
  }) async {
    final result = preview(
      raw: raw,
      existingLabels: existingLabels,
      unifiedFace: unifiedFace,
    );

    if (result.issues.isEmpty || geminiApiKey.isEmpty) return result;

    // Collect failed lines
    final lines = raw.split('\n');
    final failedLineNumbers = result.issues.map((i) => i.lineNumber).toSet();
    final failedText = failedLineNumbers
        .where((n) => n > 0 && n <= lines.length)
        .map((n) => lines[n - 1])
        .where((line) => line.trim().isNotEmpty)
        .join('\n');

    if (failedText.isEmpty) return result;

    try {
      final aiCards = await GeminiService.parseCards(geminiApiKey, failedText);
      final seenLabels = result.cards.map((c) => c.label).toSet();
      for (final card in aiCards) {
        if (seenLabels.contains(card.label)) continue;
        if (existingLabels.containsKey(card.label)) {
          result.duplicateExisting[card.label] = existingLabels[card.label]!;
          continue;
        }
        seenLabels.add(card.label);
        result.cards.add(card);
      }
      // Clear issues that were resolved by AI
      result.issues.clear();
    } catch (_) {
      // Keep original issues if AI fails
    }

    return result;
  }

  static ImportPreview preview({
    required String raw,
    required Map<String, String> existingLabels,
    double? unifiedFace,
  }) {
    final preview = ImportPreview(totalLines: raw.split('\n').length);
    final seenLabels = <String>{};
    final faceOverride = unifiedFace != null && unifiedFace > 0 ? unifiedFace : null;

    for (final entry in raw.split('\n').asMap().entries) {
      final lineNumber = entry.key + 1;
      final line = entry.value.trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
      if (parts.isEmpty) continue;

      late final String label;
      late final String secret;
      late final double face;

      if (faceOverride != null) {
        label = parts.first;
        secret = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        face = faceOverride;
      } else {
        final lastIsFace = parts.isNotEmpty && double.tryParse(parts.last) != null;
        if (!lastIsFace) {
          preview.issues.add(ImportIssue(lineNumber: lineNumber, message: '第 $lineNumber 行缺少面值'));
          continue;
        }

        face = double.tryParse(parts.last) ?? 0;
        if (parts.length >= 3) {
          label = parts.sublist(0, parts.length - 2).join(' ');
          secret = parts[parts.length - 2];
        } else if (parts.length == 2) {
          label = parts.first;
          secret = '';
        } else {
          preview.issues.add(ImportIssue(lineNumber: lineNumber, message: '第 $lineNumber 行格式无法识别'));
          continue;
        }
      }

      if (label.trim().isEmpty || face <= 0) {
        preview.issues.add(ImportIssue(lineNumber: lineNumber, message: '第 $lineNumber 行内容无效'));
        continue;
      }

      if (!seenLabels.add(label)) {
        preview.duplicateWithinInput.add(label);
        continue;
      }

      final existingBatch = existingLabels[label];
      if (existingBatch != null) {
        preview.duplicateExisting[label] = existingBatch;
        continue;
      }

      preview.cards.add(
        ParsedCardDraft(
          label: label,
          secret: secret,
          face: face,
          lineNumber: lineNumber,
        ),
      );
    }

    return preview;
  }
}
