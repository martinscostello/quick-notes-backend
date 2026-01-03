import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pasteboard/pasteboard.dart';
import '../services/api_service.dart';

class ImageHelper {
  static final ImageHelper instance = ImageHelper._();
  final ImagePicker _picker = ImagePicker();

  ImageHelper._();

  // 0. Upload Image
  Future<String?> uploadImage(String filePath) async {
      try {
          final response = await ApiService.instance.postMultipart('/upload', filePath);
          if (response != null && response['url'] != null) {
              return response['url'];
          }
          return null;
      } catch (e) {
          print("Upload failed: $e");
          return null;
      }
  }

  // 1. Pick from Gallery
  Future<String?> pickAndSaveImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;
      return _saveFileToAppDir(await File(image.path).readAsBytes()); // Async read
    } catch (e) {
      print("Error saving image: $e");
      return null;
    }
  }

  // 2. Paste Binary (System Clipboard Image)
  Future<String?> pasteImageFromClipboard() async {
      try {
          // Try fetching binary image first
          final imageBytes = await Pasteboard.image;
          if (imageBytes != null) {
              return await _saveFileToAppDir(imageBytes);
          }
          return null;
      } catch (e) {
          print("Error pasting image: $e");
          return null;
      }
  }
  
  // 3. Download from Web URL
  Future<String?> downloadImage(String url) async {
      try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
              return await _saveFileToAppDir(response.bodyBytes);
          }
          print("Failed to download image: ${response.statusCode}");
          return null;
      } catch (e) {
          print("Error downloading image: $e");
          return null;
      }
  }

  Future<String> _saveFileToAppDir(List<int> bytes) async {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDirPath = p.join(appDir.path, 'images');
      final Directory imagesDir = Directory(imagesDirPath);
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final String fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String savedPath = p.join(imagesDirPath, fileName);

      await File(savedPath).writeAsBytes(bytes);
      return savedPath;
  }
}
