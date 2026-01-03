import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class ApiService {
  // Singleton
  static final ApiService instance = ApiService._();
  ApiService._();

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.instance.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}$endpoint'), headers: headers)
        .timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return _handleResponse(response);
  }

  Future<dynamic> postMultipart(String endpoint, String filePath) async {
    final headers = await _getHeaders(); // Auth token
    var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$endpoint'));
    
    // Add Headers
    headers.forEach((key, value) {
        if (key != 'Content-Type') { // Let Multipart set the content type
            request.headers[key] = value;
        }
    });

    // Add File
    request.files.add(await http.MultipartFile.fromPath('image', filePath));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      // Throw error with message
      String message = "Unknown Error";
      try {
        final body = jsonDecode(response.body);
        message = body['message'] ?? response.reasonPhrase;
      } catch (_) {}
      throw Exception(message);
    }
  }
}
