import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova/services/worker_stt_service.dart';

void main() {
  group('WorkerSttService.workerSupportsRestStt', () {
    test('returns true when health lists stt feature', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(
          '{"ok":true,"features":["chat","tts","stt","stt-stream"]}',
          200,
        );
      });

      http.runWithClient(
        () async {
          final supported = await WorkerSttService.workerSupportsRestStt(
            'https://example.workers.dev',
          );
          expect(supported, isTrue);
        },
        () => client,
      );
    });

    test('returns false when health omits stt feature', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"ok":true,"features":["chat","tts","stt-stream"]}',
          200,
        );
      });

      http.runWithClient(
        () async {
          final supported = await WorkerSttService.workerSupportsRestStt(
            'https://example.workers.dev',
          );
          expect(supported, isFalse);
        },
        () => client,
      );
    });
  });
}
