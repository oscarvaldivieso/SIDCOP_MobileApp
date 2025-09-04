import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'GlobalService.dart';

class ImageUploadService {
  final String _apiServer = apiServer;
  final String _apiKey = apikey;
  static const String _baseUrl = apiServer;
  static const String _uploadEndpoint = '/Imagen/Subir';

  /// Returns the complete URL for displaying images
  static String getImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath; // Already a complete URL
    }
    return '$_baseUrl$imagePath';
  }

  Future<String?> uploadImage(File imageFile, {String? publicId}) async {
    try {
      final url = Uri.parse('$_baseUrl$_uploadEndpoint');
      
      // Read file as bytes
      final bytes = await imageFile.readAsBytes();
      
      // Create multipart request
      var request = http.MultipartRequest('POST', url);
      
      // Add headers
      request.headers['accept'] = '*/*';
      request.headers['X-Api-Key'] = _apiKey;
      
      // Determine content type based on file extension
      String extension = path.extension(imageFile.path).toLowerCase();
      MediaType contentType;
      switch (extension) {
        case '.png':
          contentType = MediaType('image', 'png');
          break;
        case '.jpg':
        case '.jpeg':
          contentType = MediaType('image', 'jpeg');
          break;
        default:
          contentType = MediaType('image', 'jpeg');
      }
      
      // Add file to request
      request.files.add(http.MultipartFile.fromBytes(
        'imagen',
        bytes,
        filename: path.basename(imageFile.path),
        contentType: contentType,
      ));
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imagePath = responseData['ruta'];
        return getImageUrl(imagePath); // Return complete URL
      } else {
        print('Image upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<String?> uploadImageFromBytes(Uint8List imageBytes, {String? publicId, String? fileName}) async {
    try {
      final url = Uri.parse('$_baseUrl$_uploadEndpoint');
      
      // Create multipart request
      var request = http.MultipartRequest('POST', url);
      
      // Add headers
      request.headers['accept'] = '*/*';
      request.headers['X-Api-Key'] = _apiKey;
      
      // Determine content type based on filename extension
      String finalFileName = fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';
      String extension = path.extension(finalFileName).toLowerCase();
      MediaType contentType;
      switch (extension) {
        case '.png':
          contentType = MediaType('image', 'png');
          break;
        case '.jpg':
        case '.jpeg':
          contentType = MediaType('image', 'jpeg');
          break;
        default:
          contentType = MediaType('image', 'jpeg');
          finalFileName = '${path.basenameWithoutExtension(finalFileName)}.jpg';
      }
      
      // Add file to request
      request.files.add(http.MultipartFile.fromBytes(
        'imagen',
        imageBytes,
        filename: finalFileName,
        contentType: contentType,
      ));
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imagePath = responseData['ruta'];
        return getImageUrl(imagePath); // Return complete URL
      } else {
        print('Image upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading image from bytes: $e');
      return null;
    }
  }
}
