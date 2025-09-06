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

  /// Genera el formato ZPL para imprimir factura en impresora Zebra
  /// Recibe los datos completos de la factura obtenidos del API
  static String generateZPLInvoice(Map<String, dynamic> invoiceData) {
    final data = invoiceData;
    
    // Información de la empresa
    final empresaNombre = data['coFa_NombreEmpresa'] ?? '';
    final empresaDireccion = data['coFa_DireccionEmpresa'] ?? '';
    final empresaRTN = data['coFa_RTN'] ?? '';
    final empresaTelefono = data['coFa_Telefono1'] ?? '';
    
    // Información de la factura
    final factNumero = data['fact_Numero'] ?? '';
    final factFecha = _formatDate(data['fact_FechaEmision']);
    final factTipo = data['fact_TipoDeDocumento'] ?? '';
    final factTipoVenta = data['fact_TipoVenta'] ?? '';
    
    // Información del cliente
    final clienteNombre = data['cliente'] ?? '';
    final clienteRTN = data['clie_RTN'] ?? '';
    final clienteTelefono = data['clie_Telefono'] ?? '';
    final clienteDireccion = data['diCl_DireccionExacta'] ?? '';
    
    // Información del vendedor
    final vendedorNombre = data['vendedor'] ?? '';
    
    // Totales
    final subtotal = data['fact_Subtotal']?.toString() ?? '0.00';
    final impuesto = data['fact_TotalImpuesto15']?.toString() ?? '0.00';
    final total = data['fact_Total']?.toString() ?? '0.00';
    
    // Detalles de productos
    final detalles = data['detalleFactura'] as List<dynamic>? ?? [];
    
    // Construir ZPL
    final zpl = StringBuffer();
    
    // Inicio del documento ZPL
    zpl.writeln('^XA'); // Inicio de formato
    
    // Configuración de etiqueta (ajustar según tamaño de papel)
    zpl.writeln('^LH0,0'); // Posición inicial
    zpl.writeln('^PW812'); // Ancho de papel (ajustar según tu impresora)
    
    // ENCABEZADO DE LA EMPRESA
    zpl.writeln('^CF0,30'); // Fuente para título
    zpl.writeln('^FO50,30^FD$empresaNombre^FS');
    
    zpl.writeln('^CF0,20'); // Fuente más pequeña
    zpl.writeln('^FO50,70^FD$empresaDireccion^FS');
    zpl.writeln('^FO50,100^FDRTN: $empresaRTN^FS');
    zpl.writeln('^FO50,130^FDTel: $empresaTelefono^FS');
    
    // Línea separadora
    zpl.writeln('^FO50,160^GB700,2,2^FS');
    
    // INFORMACIÓN DE LA FACTURA
    zpl.writeln('^CF0,25'); // Fuente para título de factura
    zpl.writeln('^FO50,180^FDFACTURA: $factNumero^FS');
    zpl.writeln('^CF0,18');
    zpl.writeln('^FO50,210^FDFecha: $factFecha^FS');
    zpl.writeln('^FO400,210^FDTipo: $factTipo^FS');
    zpl.writeln('^FO50,235^FDVenta: $factTipoVenta^FS');
    
    // INFORMACIÓN DEL CLIENTE
    zpl.writeln('^FO50,270^FDCliente: $clienteNombre^FS');
    zpl.writeln('^FO50,295^FDRTN: $clienteRTN^FS');
    zpl.writeln('^FO50,320^FDTel: $clienteTelefono^FS');
    if (clienteDireccion.isNotEmpty) {
      zpl.writeln('^FO50,345^FDDir: $clienteDireccion^FS');
    }
    
    zpl.writeln('^FO50,375^FDVendedor: $vendedorNombre^FS');
    
    // Línea separadora
    zpl.writeln('^FO50,405^GB700,2,2^FS');
    
    // ENCABEZADOS DE PRODUCTOS
    zpl.writeln('^CF0,16');
    zpl.writeln('^FO50,425^FDProducto^FS');
    zpl.writeln('^FO350,425^FDCant^FS');
    zpl.writeln('^FO450,425^FDPrecio^FS');
    zpl.writeln('^FO600,425^FDTotal^FS');
    zpl.writeln('^FO50,445^GB700,1,1^FS');
    
    // DETALLES DE PRODUCTOS
    int yPosition = 465;
    for (var detalle in detalles) {
      final producto = _truncateText(detalle['prod_Descripcion'] ?? '', 25);
      final cantidad = detalle['faDe_Cantidad']?.toString() ?? '0';
      final precio = detalle['faDe_PrecioUnitario']?.toString() ?? '0.00';
      final totalItem = detalle['faDe_Total']?.toString() ?? '0.00';
      
      zpl.writeln('^FO50,$yPosition^FD$producto^FS');
      zpl.writeln('^FO350,$yPosition^FD$cantidad^FS');
      zpl.writeln('^FO450,$yPosition^FDL $precio^FS');
      zpl.writeln('^FO600,$yPosition^FDL $totalItem^FS');
      
      yPosition += 25;
    }
    
    // Línea separadora antes de totales
    yPosition += 10;
    zpl.writeln('^FO50,$yPosition^GB700,2,2^FS');
    
    // TOTALES
    yPosition += 20;
    zpl.writeln('^CF0,18');
    zpl.writeln('^FO450,$yPosition^FDSubtotal:^FS');
    zpl.writeln('^FO600,$yPosition^FDL $subtotal^FS');
    
    yPosition += 25;
    zpl.writeln('^FO450,$yPosition^FDISV (15%):^FS');
    zpl.writeln('^FO600,$yPosition^FDL $impuesto^FS');
    
    yPosition += 30;
    zpl.writeln('^CF0,22'); // Fuente más grande para total
    zpl.writeln('^FO450,$yPosition^FDTOTAL:^FS');
    zpl.writeln('^FO600,$yPosition^FDL $total^FS');
    
    // Mensaje final
    yPosition += 50;
    zpl.writeln('^CF0,16');
    zpl.writeln('^FO50,$yPosition^FDGracias por su compra!^FS');
    
    // Fin del documento ZPL
    zpl.writeln('^XZ'); // Fin de formato
    
    return zpl.toString();
  }

  /// Genera un formato ZPL más compacto para tickets pequeños
  static String generateCompactZPLInvoice(Map<String, dynamic> invoiceData) {
    final data = invoiceData;
    
    final empresaNombre = data['coFa_NombreEmpresa'] ?? '';
    final factNumero = data['fact_Numero'] ?? '';
    final factFecha = _formatDate(data['fact_FechaEmision']);
    final clienteNombre = data['cliente'] ?? '';
    final total = data['fact_Total']?.toString() ?? '0.00';
    final detalles = data['detalleFactura'] as List<dynamic>? ?? [];
    
    final zpl = StringBuffer();
    
    zpl.writeln('^XA');
    zpl.writeln('^PW400'); // Ancho más pequeño para tickets
    
    // Encabezado compacto
    zpl.writeln('^CF0,20');
    zpl.writeln('^FO20,20^FD$empresaNombre^FS');
    zpl.writeln('^CF0,16');
    zpl.writeln('^FO20,50^FD$factNumero - $factFecha^FS');
    zpl.writeln('^FO20,75^FDCliente: $clienteNombre^FS');
    
    zpl.writeln('^FO20,100^GB360,1,1^FS');
    
    // Productos compactos
    int yPos = 120;
    for (var detalle in detalles) {
      final producto = _truncateText(detalle['prod_Descripcion'] ?? '', 20);
      final cantidad = detalle['faDe_Cantidad']?.toString() ?? '0';
      final totalItem = detalle['faDe_Total']?.toString() ?? '0.00';
      
      zpl.writeln('^FO20,$yPos^FD$producto^FS');
      yPos += 20;
      zpl.writeln('^FO20,$yPos^FD$cantidad x L$totalItem^FS');
      yPos += 25;
    }
    
    // Total
    yPos += 10;
    zpl.writeln('^FO20,$yPos^GB360,1,1^FS');
    yPos += 15;
    zpl.writeln('^CF0,20');
    zpl.writeln('^FO20,$yPos^FDTOTAL: L $total^FS');
    
    yPos += 40;
    zpl.writeln('^CF0,14');
    zpl.writeln('^FO20,$yPos^FDGracias por su compra!^FS');
    
    zpl.writeln('^XZ');
    
    return zpl.toString();
  }

  /// Formatea una fecha ISO a formato legible
  static String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
    
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return isoDate;
    }
  }

  /// Trunca texto a una longitud específica
  static String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Envía el comando ZPL a la impresora Zebra
  /// Este método necesitará ser implementado según tu método de conexión
  /// (USB, Bluetooth, WiFi, etc.)
  static Future<bool> printZPLToZebra(String zplCommand, {String? printerAddress}) async {
    try {
      // TODO: Implementar conexión con impresora Zebra
      // Esto dependerá del tipo de conexión que uses:
      // - Para USB: usar plugin como usb_serial
      // - Para Bluetooth: usar flutter_bluetooth_serial
      // - Para WiFi: usar socket TCP/IP
      
      print('ZPL Command to send:');
      print(zplCommand);
      
      // Por ahora solo imprimimos el comando para debug
      // En producción, aquí enviarías el comando a la impresora
      
      return true;
    } catch (e) {
      print('Error enviando a impresora Zebra: $e');
      return false;
    }
  }
}
