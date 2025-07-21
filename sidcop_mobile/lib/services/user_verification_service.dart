import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/user_verification_model.dart';
import '../models/reset_password_request.dart';

class UserVerificationService {
  // Base URL - Update this with your actual base URL
  static const String _baseUrl = 'https://localhost:7071';
  
  // API Key - Consider using flutter_dotenv or similar for production
  static const String _apiKey = 'bdccf3f3-d486-4e1e-ab44-74081aefcdbc';
  
  // Store the generated verification code and session ID
  static String? _verificationCode;
  static String? _verificationSessionId;
  static String? _lastVerifiedEmail;
  
  // Generate a random 5-digit code
  static String _generateVerificationCode() {
    final random = Random();
    return (10000 + random.nextInt(90000)).toString(); // Ensures 5 digits
  }
  
  // Generate a unique session ID
  static String _generateSessionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

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
  
  /// Sends a verification code to the specified email
  /// 
  /// [email] The email address to send the code to
  /// Returns true if the code was sent successfully, false otherwise
  static Future<bool> sendVerificationCode(String email, {bool isResend = false}) async {
    final url = Uri.parse('$_baseUrl/Usuarios/EnviarCorreo');
    final currentSession = _generateSessionId();
    
    // Generate new code if:
    // 1. It's not a resend request, or
    // 2. The email has changed, or
    // 3. We don't have a code yet
    if (!isResend || _lastVerifiedEmail != email || _verificationCode == null) {
      _verificationCode = _generateVerificationCode();
      _verificationSessionId = currentSession;
      _lastVerifiedEmail = email;
      print('Generated new verification code: $_verificationCode (session: $_verificationSessionId)');
    } else {
      print('Reusing verification code for $email in same session (session: $_verificationSessionId)');
    }
    
    try {
      final response = await http.post(
        url,
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to_email': email,
          'codigo': _verificationCode,
        }),
      );
      
      print('Verification code response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to send verification code. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error sending verification code: $e');
      return false;
    }
  }
  
  /// Validates if the provided code matches the sent verification code
  /// 
  /// [code] The code to validate
  /// [email] The email being verified (must match the one the code was sent to)
  /// Returns true if the code matches, false otherwise
  static bool validateVerificationCode(String code, String email) {
    if (_verificationCode == null) {
      print('No verification code was generated');
      return false;
    }
    
    if (_lastVerifiedEmail != email) {
      print('Email mismatch in verification. Expected: $_lastVerifiedEmail, got: $email');
      return false;
    }
    
    final isValid = _verificationCode == code;
    print('Verification code validation result: $isValid (expected: $_verificationCode, got: $code)');
    
    // Clear the code after validation (whether successful or not)
    if (isValid) {
      _verificationCode = null;
      _verificationSessionId = null;
      _lastVerifiedEmail = null;
    }
    
    return isValid;
  }

  /// Resets the user's password
  /// 
  /// [request] The reset password request containing user details and new password
  /// Returns true if password was reset successfully, false otherwise
  static Future<bool> resetPassword(ResetPasswordRequest request) async {
    final url = Uri.parse('$_baseUrl/Usuarios/RestablecerClave');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'accept': '*/*',
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
      
      print('Reset password response: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        return true;
      } else {
        print('Failed to reset password. Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }
}
