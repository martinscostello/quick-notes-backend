import 'dart:io';

class ApiConfig {
  // Set your Render Application URL here (e.g., https://my-app.onrender.com/api)
  // Usage: "https://your-app-name.onrender.com/api"
  static const String? _productionUrl = null; 

  static String get baseUrl {
    if (_productionUrl != null && _productionUrl!.isNotEmpty) {
      return _productionUrl!;
    }
    if (Platform.isAndroid) {
      return "http://10.0.2.2:5001/api";
    }
    // iOS Simulator or macOS Desktop
    return "http://localhost:5001/api";
  }
}
