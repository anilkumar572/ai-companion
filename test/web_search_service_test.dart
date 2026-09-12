import 'package:flutter_test/flutter_test.dart';
import 'package:nova/services/web_search_service.dart';

void main() {
  test('Web search returns useful answer for common topic', () async {
    final service = WebSearchService();
    final result = await service.search('Flutter framework');

    expect(result.trim(), isNotEmpty);
    expect(result.toLowerCase(), isNot(contains('could not find reliable information')));
  }, skip: !const bool.fromEnvironment('RUN_NETWORK_TESTS', defaultValue: false));
}
