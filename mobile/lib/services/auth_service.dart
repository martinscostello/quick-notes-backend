import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'api_config.dart'; // Just to be safe, though ApiService handles calls
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final _storage = const FlutterSecureStorage();
  String? _cachedToken;

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    _cachedToken = await _storage.read(key: 'jwt_token');
    return _cachedToken;
  }

  Future<bool> isLoggedIn() async {
    return (await getToken()) != null;
  }

  // Direct HTTP call to avoid circular dependency with ApiService for simple auth endpoints
  // Or we can use ApiService if we handle the token requirement carefully.
  // Actually, ApiService automatically adds token if present. For login/signup we don't need it.

  Future<void> login(String email, String password) async {
     // We can't use ApiService.post because it imports AuthService (Circular Dependecy Risk if not careful, but Dart handles it okay mostly at runtime)
     // But to be clean, let's use http directly for auth.
     
     final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password})
     ).timeout(const Duration(seconds: 15));

     if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         final token = data['token'];
         await _saveToken(token);
     } else {
         final body = jsonDecode(response.body);
         throw Exception(body['message'] ?? 'Login failed');
     }
  }

  Future<void> signup(String email, String password) async {
     final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password})
     ).timeout(const Duration(seconds: 15));

     if (response.statusCode == 201) {
         final data = jsonDecode(response.body);
         final token = data['token'];
         await _saveToken(token);
     } else {
         final body = jsonDecode(response.body);
         throw Exception(body['message'] ?? 'Signup failed');
     }
  }

  Future<void> logout() async {
    _cachedToken = null;
    await _storage.delete(key: 'jwt_token');
  }

  Future<void> _saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: 'jwt_token', value: token);
  }
}
