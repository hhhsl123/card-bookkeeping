import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/data.dart';

class GeminiService {
  static Future<List<ParsedCardDraft>> parseCards(
    String apiKey,
    String rawText,
  ) async {
    final prompt = '''You are a card data extractor. Extract gift card information from the following text.
For each card, identify:
- label: the card number/identifier (required)
- secret: the card secret/PIN/code (optional, empty string if not found)
- face: the face value as a number (required)

Return ONLY a JSON array, no other text. Example:
[{"label": "ABC-123", "secret": "9876", "face": 25}]

If you cannot identify a face value for a card, try to infer it from context. If impossible, use 0.

Text to parse:
$rawText''';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return [];

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return [];

    final text = (parts[0]['text'] ?? '').toString().trim();
    final List<dynamic> cards = jsonDecode(text) as List<dynamic>;

    final results = <ParsedCardDraft>[];
    for (var i = 0; i < cards.length; i++) {
      final card = cards[i] as Map<String, dynamic>;
      final label = (card['label'] ?? '').toString().trim();
      final secret = (card['secret'] ?? '').toString().trim();
      final face = (card['face'] is num) ? (card['face'] as num).toDouble() : (double.tryParse(card['face']?.toString() ?? '') ?? 0);
      if (label.isNotEmpty && face > 0) {
        results.add(ParsedCardDraft(
          label: label,
          secret: secret,
          face: face,
          lineNumber: i + 1,
        ));
      }
    }
    return results;
  }
}
