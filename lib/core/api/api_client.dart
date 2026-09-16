import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../utils/safe_error_message.dart';

class ApiClient {
  static Future<Map<String, dynamic>> get(String url) async {
    try {
      print('🔄 GET: ${SafeErrorMessage.redactedForLog(url)}');

      final response = await http
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
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
        final msg = decoded?['msg']?.toString();
        throw Exception(
          msg != null
              ? SafeErrorMessage.sanitizeText(msg, fallback: SafeErrorMessage.serviceUpdating)
              : SafeErrorMessage.serviceUpdating,
        );
      }

      if (decoded == null) {
        throw Exception(SafeErrorMessage.serviceUpdating);
      }

      final status = decoded['status'];
      if (status == false) {
        final msg = decoded['msg']?.toString();
        throw Exception(
          msg != null
              ? SafeErrorMessage.sanitizeText(msg, fallback: SafeErrorMessage.serviceUpdating)
              : SafeErrorMessage.serviceUpdating,
        );
      }

      return decoded;
    } catch (e) {
      print('❌ ApiClient error: ${SafeErrorMessage.redactedForLog(e)}');
      if (e is Exception) {
        rethrow;
      }
      throw Exception(SafeErrorMessage.serviceUpdating);
    }
  }
}