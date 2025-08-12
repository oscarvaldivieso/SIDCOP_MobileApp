import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ErrorHandler {
  /// Maneja errores del backend y muestra toast apropiado
  static void handleBackendError(Map<String, dynamic>? response, {String? fallbackMessage}) {
    String errorMessage = _extractErrorMessage(response, fallbackMessage);
    showErrorToast(errorMessage);
  }

  /// Extrae el mensaje de error de la respuesta del backend
  static String _extractErrorMessage(Map<String, dynamic>? response, String? fallbackMessage) {
    if (response == null) {
      return fallbackMessage ?? 'Error de conexión. Intenta nuevamente.';
    }

    // Debug: imprimir la respuesta para verificar estructura
    print('🔍 DEBUG - Respuesta completa: $response');
    
    // PRIORIDAD 1: Buscar message_Status en data
    String? messageStatus = _extractMessageStatus(response);
    if (messageStatus != null && messageStatus.trim().isNotEmpty) {
      print('🔍 DEBUG - ✅ Usando message_Status: $messageStatus');
      return messageStatus.trim();
    }

    // PRIORIDAD 2: Usar el message principal
    if (response['message'] != null && response['message'].toString().trim().isNotEmpty) {
      print('🔍 DEBUG - ⚠️ Usando message principal: ${response['message']}');
      return response['message'].toString().trim();
    }

    // PRIORIDAD 3: Fallback con código si está disponible
    String codeInfo = '';
    if (response['code'] != null) {
      codeInfo = ' (Código: ${response['code']})';
    }

    print('🔍 DEBUG - ❌ Usando fallback message');
    return (fallbackMessage ?? 'Error al realizar la operación') + codeInfo;
  }

  /// Extrae específicamente el message_Status de la respuesta
  static String? _extractMessageStatus(Map<String, dynamic> response) {
    try {
      // Método 1: Acceso directo a data.message_Status
      if (response['data'] != null && response['data'] is Map<String, dynamic>) {
        var data = response['data'] as Map<String, dynamic>;
        if (data['message_Status'] != null) {
          String messageStatus = data['message_Status'].toString();
          print('🔍 DEBUG - message_Status encontrado (acceso directo): $messageStatus');
          return messageStatus;
        }
      }

      // Método 2: Búsqueda recursiva como fallback
      var foundMessage = _findValueByKey(response, 'message_Status');
      if (foundMessage != null) {
        String messageStatus = foundMessage.toString();
        print('🔍 DEBUG - message_Status encontrado (búsqueda recursiva): $messageStatus');
        return messageStatus;
      }
    } catch (e) {
      print('🔍 DEBUG - Error extrayendo message_Status: $e');
    }
    
    return null;
  }
  
  /// Busca recursivamente un valor por clave en un Map anidado
  static dynamic _findValueByKey(dynamic obj, String key) {
    if (obj is Map) {
      if (obj.containsKey(key)) {
        return obj[key];
      }
      for (var value in obj.values) {
        var result = _findValueByKey(value, key);
        if (result != null) return result;
      }
    } else if (obj is List) {
      for (var item in obj) {
        var result = _findValueByKey(item, key);
        if (result != null) return result;
      }
    }
    return null;
  }

  /// Muestra toast de error con estilo personalizado
  static void showErrorToast(String message) {
    print('🚨 MOSTRANDO ERROR TOAST: $message');
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 5,
      backgroundColor: const Color(0xFFE53E3E), // Rojo más suave
      textColor: Colors.white,
      fontSize: 15.0,
      webBgColor: "linear-gradient(to right, #E53E3E, #C53030)",
      webPosition: "center",
    );
  }

  /// Muestra toast de éxito
  static void showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: const Color(0xFF38A169), // Verde más vibrante
      textColor: Colors.white,
      fontSize: 15.0,
      webBgColor: "linear-gradient(to right, #38A169, #2F855A)",
      webPosition: "center",
    );
  }

  /// Muestra toast informativo
  static void showInfoToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 3,
      backgroundColor: const Color(0xFF2B6CB0), // Azul más claro y amigable
      textColor: Colors.white,
      fontSize: 15.0,
      webBgColor: "linear-gradient(to right, #2B6CB0, #2C5282)",
      webPosition: "center",
    );
  }

  /// Muestra toast de advertencia
  static void showWarningToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 4,
      backgroundColor: const Color(0xFFED8936), // Naranja más suave
      textColor: Colors.white,
      fontSize: 15.0,
      webBgColor: "linear-gradient(to right, #ED8936, #DD6B20)",
      webPosition: "center",
    );
  }

  /// Valida si una respuesta del backend indica éxito
  static bool isSuccessResponse(Map<String, dynamic>? response) {
    if (response == null) return false;
    return response['success'] == true;
  }

  /// Valida si una respuesta del backend indica error
  static bool isErrorResponse(Map<String, dynamic>? response) {
    if (response == null) return true;
    return response['success'] == false;
  }
}