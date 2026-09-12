import 'package:flutter_test/flutter_test.dart';
import 'package:nova/models/tts_engine.dart';

void main() {
  test('TtsEngine restores from storage', () {
    expect(TtsEngine.fromStorage('cartesia'), TtsEngine.cartesia);
    expect(TtsEngine.fromStorage('device'), TtsEngine.device);
    expect(TtsEngine.fromStorage(null), TtsEngine.device);
    expect(TtsEngine.fromStorage('unknown'), TtsEngine.device);
  });
}
