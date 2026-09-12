import 'dart:convert';

import 'package:http/http.dart' as http;

class WebSearchService {
  Future<String> search(String query) async {
    final cleaned = query.trim();
    if (cleaned.isEmpty) {
      return 'Please tell me what you would like me to search for.';
    }

    final wikipedia = await _searchWikipedia(cleaned);
    if (wikipedia != null) {
      return wikipedia;
    }

    final duckDuckGo = await _searchDuckDuckGo(cleaned);
    if (duckDuckGo != null) {
      return duckDuckGo;
    }

    final duckHtml = await _searchDuckDuckGoHtml(cleaned);
    if (duckHtml != null) {
      return duckHtml;
    }

    return 'I could not find reliable information for "$cleaned". Please try rephrasing your question.';
  }

  Future<String?> _searchWikipedia(String query) async {
    try {
      final searchUri = Uri.https('en.wikipedia.org', '/w/api.php', {
        'action': 'query',
        'list': 'search',
        'srsearch': query,
        'format': 'json',
        'srlimit': '1',
        'origin': '*',
      });

      final searchResponse =
          await http.get(searchUri).timeout(const Duration(seconds: 8));
      if (searchResponse.statusCode != 200) return null;

      final searchData = jsonDecode(searchResponse.body) as Map<String, dynamic>;
      final results = (searchData['query'] as Map<String, dynamic>?)?['search']
          as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final title = (results.first as Map<String, dynamic>)['title'] as String?;
      if (title == null || title.isEmpty) return null;

      final summaryUri = Uri.parse(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
      );
      final summaryResponse =
          await http.get(summaryUri).timeout(const Duration(seconds: 8));
      if (summaryResponse.statusCode != 200) return null;

      final summaryData =
          jsonDecode(summaryResponse.body) as Map<String, dynamic>;
      final extract = (summaryData['extract'] as String?)?.trim();
      if (extract == null || extract.isEmpty) return null;

      return _truncate('$title. $extract', 480);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _searchDuckDuckGo(String query) async {
    try {
      final uri = Uri.https('api.duckduckgo.com', '/', {
        'q': query,
        'format': 'json',
        'no_redirect': '1',
        'no_html': '1',
        'skip_disambig': '1',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final abstract = (data['AbstractText'] as String?)?.trim();
      final heading = (data['Heading'] as String?)?.trim();

      if (abstract != null && abstract.isNotEmpty) {
        if (heading != null && heading.isNotEmpty) {
          return _truncate('$heading. $abstract', 480);
        }
        return _truncate(abstract, 480);
      }

      final relatedTexts = _collectRelatedTopics(data['RelatedTopics']);
      if (relatedTexts.isNotEmpty) {
        return _truncate(relatedTexts.join('. '), 480);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _searchDuckDuckGoHtml(String query) async {
    try {
      final uri = Uri.https('html.duckduckgo.com', '/html/', {'q': query});
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'NovaCompanion/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = response.body;
      final snippetMatch = RegExp(
        r'class="result__snippet"[^>]*>([^<]+)',
        caseSensitive: false,
      ).firstMatch(body);

      if (snippetMatch != null) {
        final snippet = _decodeHtml(snippetMatch.group(1) ?? '').trim();
        if (snippet.isNotEmpty) {
          return _truncate(snippet, 480);
        }
      }

      final titleMatch = RegExp(
        r'class="result__a"[^>]*>([^<]+)',
        caseSensitive: false,
      ).firstMatch(body);

      if (titleMatch != null) {
        final title = _decodeHtml(titleMatch.group(1) ?? '').trim();
        if (title.isNotEmpty) {
          return 'Top result: $title';
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  List<String> _collectRelatedTopics(dynamic topics) {
    final results = <String>[];
    if (topics is! List<dynamic>) return results;

    for (final topic in topics) {
      if (topic is Map<String, dynamic>) {
        final text = topic['Text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          results.add(text.trim());
        }

        final nested = topic['Topics'];
        results.addAll(_collectRelatedTopics(nested));
      }
      if (results.length >= 3) break;
    }

    return results;
  }

  String _decodeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3).trim()}...';
  }
}
