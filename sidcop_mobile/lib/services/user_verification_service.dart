import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_verification_model.dart';

class UserVerificationService {
  // Base URL - Update this with your actual base URL
  static const String _baseUrl = 'https://localhost:7071';
  
  // API Key - Consider using flutter_dotenv or similar for production
  static const String _apiKey = 'bdccf3f3-d486-4e1e-ab44-74081aefcdbc';

  /// Verifies a user by their username and returns their email if found
  /// 
  /// [username] The username to verify
  /// Returns a [UserVerificationResponse] if successful, null otherwise
  /// Throws an exception if the request fails
  static Future<UserVerificationResponse?> verifyUser(String username) async {
    final url = Uri.parse('$_baseUrl/Usuarios/VerificarUsuario');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'usua_Usuario': username,
          'usua_Clave': '', // Required field, but can be empty for verification
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Parse the response
        final responseData = jsonDecode(response.body);
        
        // Create the response object
        final verificationResponse = UserVerificationResponse.fromJson(responseData);
        
        // Check if the request was successful and we have data
        if (verificationResponse.success && verificationResponse.data.isNotEmpty) {
          return verificationResponse;
        } else {
          print('No user data found or request was not successful');
          return null;
        }
      } else {
        // If the server did not return a 200 OK response,
        // throw an exception with the status code
        throw Exception('Failed to verify user. Status code: ${response.statusCode}');
      }
    } catch (e) {
      // Handle any errors that occurred during the HTTP request
      print('Error in verifyUser: $e');
      rethrow;
    }
  }
  
  /// Extracts just the email from the verification response
  /// 
  /// [username] The username to get the email for
  /// Returns the email as a String if found, null otherwise
  static Future<String?> getUserEmail(String username) async {
    try {
      final response = await verifyUser(username);
      if (response != null && 
          response.data.isNotEmpty && 
          response.data.first.correo != null && 
          response.data.first.correo!.isNotEmpty) {
        return response.data.first.correo;
      }
      return null;
    } catch (e) {
      print('Error in getUserEmail: $e');
      rethrow;
    }
  }
}
