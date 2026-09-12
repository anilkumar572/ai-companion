import 'dart:convert';

import 'package:http/http.dart' as http;

class WorkerHealthService {
  const WorkerHealthService();

  Future<bool> supportsRestStt(String workerBaseUrl) async {
    try {
      final base = workerBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final response = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'];
      if (features is! List) return false;

      return features.any((feature) => feature?.toString() == 'stt');
    } catch (_) {
      return false;
    }
  }
}
