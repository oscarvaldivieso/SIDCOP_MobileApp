class InvoiceUtils {
  // Genera el siguiente número de factura basado en el último número
  static String getNextInvoiceNumber(String? lastInvoiceNumber) {
    // Si no hay último número, empezamos desde 1
    if (lastInvoiceNumber == null || lastInvoiceNumber.isEmpty) {
      return 'F001-0000001';
    }

    try {
      // Extraer el prefijo (ej: 'F001') y el número secuencial
      final parts = lastInvoiceNumber.split('-');
      if (parts.length != 2) return 'F001-0000001';
      
      final prefix = parts[0];
      final currentNumber = int.tryParse(parts[1]) ?? 0;
      final nextNumber = currentNumber + 1;
      
      // Formatear el número con ceros a la izquierda
      final nextNumberStr = nextNumber.toString().padLeft(7, '0');
      return '$prefix-$nextNumberStr';
    } catch (e) {
      print('Error generando número de factura: $e');
      return 'F001-0000001';
    }
  }
}
