import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class CloudinaryService {
  static const String _cloudName = 'dbt7mxrwk';
  static const String _apiKey = '134792964771762';
  static const String _apiSecret = 'ImAB6ob6wd7HosRxpmPeVGQ-Xs0';
  static const String _uploadPreset = 'ml_default';
  static const String _folder = 'Clientes';

  Future<String?> uploadImage(File imageFile, {String? publicId}) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/upload',
      );

      // Read file as bytes
      final bytes = await imageFile.readAsBytes();

      // Create multipart request
      var request = http.MultipartRequest('POST', url);

      // Add file to request
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename:
              '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Add other parameters
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = _folder;

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['secure_url'];
      } else {
        print(
          'Cloudinary upload failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  Future<String?> uploadImageFromBytes(
    Uint8List imageBytes, {
    String? publicId,
    String? fileName,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/upload',
      );

      // Create multipart request
      var request = http.MultipartRequest('POST', url);

      // Add file to request
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Add other parameters
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = _folder;

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['secure_url'];
      } else {
        print(
          'Cloudinary upload failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary from bytes: $e');
      return null;
    }
  }
}
