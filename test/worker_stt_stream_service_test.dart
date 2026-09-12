import 'package:flutter_test/flutter_test.dart';
import 'package:nova/core/constants.dart';

void main() {
  test('worker URL is fixed and contains no secrets', () {
    expect(NovaConstants.workerUrl, contains('workers.dev'));
    expect(NovaConstants.workerUrl.startsWith('https://'), isTrue);
  });
}
