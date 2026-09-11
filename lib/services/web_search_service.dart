import 'dart:convert';

import 'package:http/http.dart' as http;

class WebSearchService {
  Future<String> search(String query) async {
    final uri = Uri.https(
      'api.duckduckgo.com',
      '/',
      {
        'q': query,
        'format': 'json',
        'no_redirect': '1',
        'no_html': '1',
        'skip_disambig': '1',
      },
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return 'I was unable to complete the web search at this time.';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final abstract = (data['AbstractText'] as String?)?.trim();
      final heading = (data['Heading'] as String?)?.trim();

      if (abstract != null && abstract.isNotEmpty) {
        if (heading != null && heading.isNotEmpty) {
          return '$heading. $abstract';
        }
        return abstract;
      }

      final related = (data['RelatedTopics'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map((topic) => topic['Text'] as String?)
          .whereType<String>()
          .take(2)
          .toList();

      if (related != null && related.isNotEmpty) {
        return related.join('. ');
      }

      return 'I found no concise results for "$query". Please refine your request.';
    } catch (_) {
      return 'The web search service is currently unavailable.';
    }
  }
}
