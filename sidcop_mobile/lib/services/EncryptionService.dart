import 'package:encrypt/encrypt.dart' as encrypt;

/// Servicio para encriptar y desencriptar datos sensibles
class EncryptionService {
  // Clave de exactamente 32 caracteres para AES-256
  static const String _keyString = 'SIDCOP2024SecureKeyForOffline32!';
  static final _key = encrypt.Key.fromUtf8(_keyString);
  static final _iv = encrypt.IV.fromLength(16); // IV de 16 bytes
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));
  
  /// Encripta un texto plano
  static String encriptar(String textoPlano) {
    try {
      final textoCifrado = _encrypter.encrypt(textoPlano, iv: _iv);
      return textoCifrado.base64;
    } catch (e) {
      print('Error encriptando datos: $e');
      throw Exception('Error al encriptar datos: $e');
    }
  }
  
  /// Desencripta un texto cifrado
  static String desencriptar(String textoCifrado) {
    try {
      final textoPlano = _encrypter.decrypt64(textoCifrado, iv: _iv);
      return textoPlano;
    } catch (e) {
      print('Error desencriptando datos: $e');
      throw Exception('Error al desencriptar datos: $e');
    }
  }
  
  /// Verifica si un texto está encriptado (intenta desencriptarlo)
  static bool esTextoEncriptado(String texto) {
    try {
      desencriptar(texto);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Genera una clave aleatoria para mayor seguridad (opcional)
  static String generarClaveAleatoria() {
    final key = encrypt.Key.fromSecureRandom(32);
    return key.base64;
  }
  
  /// Genera un IV aleatorio para mayor seguridad (opcional)
  static String generarIVAleatorio() {
    final iv = encrypt.IV.fromSecureRandom(16);
    return iv.base64;
  }
  
  /// Encripta datos JSON (útil para objetos complejos)
  static String encriptarJson(Map<String, dynamic> data) {
    try {
      final jsonString = data.toString();
      return encriptar(jsonString);
    } catch (e) {
      print('Error encriptando JSON: $e');
      throw Exception('Error al encriptar JSON: $e');
    }
  }
  
  /// Desencripta datos JSON
  static Map<String, dynamic> desencriptarJson(String textoCifrado) {
    try {
      final jsonString = desencriptar(textoCifrado);
      // Nota: En producción, usar jsonDecode para parsing más robusto
      return {}; // Placeholder - implementar parsing según necesidad
    } catch (e) {
      print('Error desencriptando JSON: $e');
      throw Exception('Error al desencriptar JSON: $e');
    }
  }
}
