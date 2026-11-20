import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/safe_error_message.dart';
import 'api_keys.dart';

class ApiClient {
  static Future<Map<String, dynamic>> get(String url) async {
    print('🔄 GET: ${SafeErrorMessage.redactedForLog(url)}');

    final token = ApiKeys.almurakibToken.trim();
    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'Accept': 'application/json',
            if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            if (token.isNotEmpty) 'X-Gateway-Key': token,
            if (token.isNotEmpty) 'x-api-key': token,
          },
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception(SafeErrorMessage.serviceUpdating),
        );

    print('📡 Status: ${response.statusCode}');

    Map<String, dynamic>? decoded;
    try {
      final dynamic tmp = json.decode(response.body);
      if (tmp is Map<String, dynamic>) decoded = tmp;
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode != 200) {
      final msg = decoded?['msg']?.toString() ?? decoded?['message']?.toString();
      throw Exception(
        msg != null
            ? SafeErrorMessage.sanitizeText(
                msg,
                fallback: SafeErrorMessage.serviceUpdating,
              )
            : SafeErrorMessage.serviceUpdating,
      );
    }

    if (decoded == null) {
      throw Exception(SafeErrorMessage.serviceUpdating);
    }

    final status = decoded['status'] ?? decoded['success'];
    if (status == false) {
      final msg = decoded['msg']?.toString() ?? decoded['message']?.toString();
      throw Exception(
        msg != null
            ? SafeErrorMessage.sanitizeText(
                msg,
                fallback: SafeErrorMessage.serviceUpdating,
              )
            : SafeErrorMessage.serviceUpdating,
      );
    }

    return decoded;
  }
}
