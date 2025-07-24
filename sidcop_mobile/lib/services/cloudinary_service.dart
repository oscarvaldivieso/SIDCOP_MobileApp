import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;

class CloudinaryService {
  static const String _cloudName = 'dbt7mxrwk';
  static const String _uploadPreset = 'ml_default';
  static const String _folder = 'Clientes';

  Future<String?> uploadImage(File imageFile, {String? publicId}) async {
    try {
      final fileName = publicId ?? 
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = _folder;
      
      final fileExtension = path.extension(imageFile.path).replaceAll('.', '');
      final mimeType = _getMimeType(fileExtension);
      
      final fileStream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        length,
        filename: fileName,
        contentType: MediaType('image', mimeType),
      );
      
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['secure_url'];
      } else {
        print('Cloudinary upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary: $e');
      return null;
    }
  }
  
  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }

  Future<String?> uploadImageFromBytes(Uint8List imageBytes, {String? publicId, String? fileName}) async {
    try {
      final uniqueFileName = fileName ?? '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = _folder;
      
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: uniqueFileName,
        contentType: MediaType('image', 'jpeg'),
      );
      
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['secure_url'];
      } else {
        print('Cloudinary upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error uploading to Cloudinary from bytes: $e');
      return null;
    }
  }
}
