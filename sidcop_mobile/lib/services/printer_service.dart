import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterService {
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  bool _isConnected = false;
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Singleton pattern
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  // Getters
  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // UUID corregido para Zebra ZQ310
  static const String ZEBRA_SERVICE_UUID = "38eb4a80-c570-11e3-9507-0002a5d5c51b";
  // CAMBIO PRINCIPAL: Usar la característica que SÍ es escribible
  static const String ZEBRA_WRITE_UUID = "38eb4a82-c570-11e3-9507-0002a5d5c51b";

  // Helper method to identify potential printer devices
  bool _isPotentialPrinter(String deviceName) {
    String name = deviceName.toLowerCase();
    return name.contains('zebra') ||
           name.contains('zq') ||
           name.contains('printer') ||
           name.contains('print') ||
           name.contains('thermal') ||
           name.contains('pos') ||
           name.contains('receipt') ||
           name.contains('label') ||
           name.contains('mobile') ||
           name.contains('portable');
  }

  // Check and request Bluetooth permissions
  Future<bool> _checkPermissions() async {
    try {
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint("Bluetooth not supported by this device");
        return false;
      }

      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('Bluetooth is not on. Current state: $adapterState');
        return false;
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      return statuses.values.every((status) => 
        status.isGranted || status.isLimited
      );
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  // Start scanning for Bluetooth devices
  Future<List<BluetoothDevice>> startScan() async {
    if (!await _checkPermissions()) {
      throw Exception('Se requieren permisos de Bluetooth para continuar');
    }

    _devices = [];
    _isScanning = true;

    try {
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.bondedDevices;
      
      debugPrint('Found ${systemDevices.length} bonded devices');
      _devices = systemDevices.where((device) => 
        device.platformName.isNotEmpty
      ).toList();

      await _scanSubscription?.cancel();
      
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          if (device.platformName.isNotEmpty &&
              !_devices.any((d) => d.remoteId == device.remoteId)) {
            _devices.add(device);
            debugPrint('Found new device: ${device.platformName}');
          }
        }
      });

      await Future.delayed(const Duration(seconds: 10));
      await FlutterBluePlus.stopScan();
      _isScanning = false;

      return _devices;
    } catch (e) {
      _isScanning = false;
      debugPrint('Error scanning for devices: $e');
      rethrow;
    }
  }

  // Connect to a Bluetooth device - OPTIMIZADO PARA ZQ310
  Future<bool> connect(BluetoothDevice device) async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      _connectedDevice = device;
      debugPrint('Connecting to ${device.platformName} (${device.remoteId})');

      // Conectar con timeout más largo para ZQ310
      await device.connect(
        timeout: const Duration(seconds: 20),
        autoConnect: false,
        mtu: null // Usar MTU por defecto
      );
      
      // Esperar más tiempo para establecer conexión estable
      await Future.delayed(const Duration(seconds: 3));
      
      var connectionState = await device.connectionState.first;
      if (connectionState != BluetoothConnectionState.connected) {
        throw Exception('Failed to establish connection');
      }
      
      // Configurar MTU para mejor transferencia de datos
      try {
        int mtu = await device.requestMtu(512);
        debugPrint('MTU set to: $mtu');
      } catch (e) {
        debugPrint('Could not set MTU: $e');
      }
      
      List<BluetoothService> services = await device.discoverServices();
      debugPrint('Found ${services.length} services');
      
      _writeCharacteristic = await _findZebraWriteCharacteristic(services);
      
      if (_writeCharacteristic == null) {
        throw Exception('No se encontró característica de escritura compatible con Zebra');
      }

      _isConnected = true;
      debugPrint('Successfully connected to ${device.platformName}');
      
      // NO inicializar impresora automáticamente - puede causar problemas
      // await _initializePrinter();
      
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _isConnected = false;
      _connectedDevice = null;
      _writeCharacteristic = null;
      return false;
    }
  }

  // MÉTODO CORREGIDO: Encontrar característica escribible para Zebra ZQ310
  Future<BluetoothCharacteristic?> _findZebraWriteCharacteristic(List<BluetoothService> services) async {
    BluetoothCharacteristic? zebraChar;
    BluetoothCharacteristic? fallbackChar;
    
    // Examinar TODOS los servicios y características
    for (BluetoothService service in services) {
      String serviceUuid = service.uuid.toString().toLowerCase();
      debugPrint('Service: $serviceUuid');
      
      bool isZebraService = serviceUuid.contains('38eb4a80') || serviceUuid.contains('c570-11e3');
      if (isZebraService) {
        debugPrint('>>> ZEBRA SERVICE FOUND <<<');
      }
      
      for (BluetoothCharacteristic char in service.characteristics) {
        String charUuid = char.uuid.toString().toLowerCase();
        debugPrint('  Characteristic: $charUuid');
        debugPrint('    Properties: write=${char.properties.write}, writeWithoutResponse=${char.properties.writeWithoutResponse}, notify=${char.properties.notify}, indicate=${char.properties.indicate}');
        
        // PRIORIDAD 1: Zebra 38eb4a82 (la que SÍ es escribible)
        if (isZebraService && charUuid.contains('38eb4a82') && char.properties.write) {
          debugPrint('  >>> ZEBRA WRITABLE CHARACTERISTIC FOUND (38eb4a82) <<<');
          zebraChar = char;
          break; // Esta es la que queremos
        }
        
        // PRIORIDAD 2: Zebra 38eb4a84 si tiene write
        if (isZebraService && charUuid.contains('38eb4a84') && char.properties.write) {
          debugPrint('  >>> ZEBRA ALTERNATIVE WRITABLE CHARACTERISTIC FOUND (38eb4a84) <<<');
          if (zebraChar == null) zebraChar = char;
        }
        
        // Fallback: Cualquier característica escribible
        if ((char.properties.writeWithoutResponse || char.properties.write) && fallbackChar == null) {
          debugPrint('    >>> WRITABLE CHARACTERISTIC FOUND (fallback) <<<');
          fallbackChar = char;
        }
      }
      
      // Si ya encontramos la característica Zebra correcta, salir del loop
      if (zebraChar != null && zebraChar.uuid.toString().toLowerCase().contains('38eb4a82')) {
        break;
      }
    }
    
    // Prioridad: Zebra específica > Fallback writable
    if (zebraChar != null) {
      debugPrint('Using Zebra characteristic: ${zebraChar.uuid}');
      return zebraChar;
    } else if (fallbackChar != null) {
      debugPrint('Using fallback writable characteristic: ${fallbackChar.uuid}');
      return fallbackChar;
    }
    
    debugPrint('❌ No writable characteristic found');
    return null;
  }

  // MÉTODO SIMPLIFICADO: Sin inicialización automática
  Future<void> _initializePrinter() async {
    try {
      debugPrint('Initializing Zebra printer...');
      
      // Solo un comando simple de status
      await _sendRawCommand('~HS');
      
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('Printer initialization complete');
      
    } catch (e) {
      debugPrint('Error initializing printer: $e');
    }
  }

  // MÉTODO CORREGIDO: Usar writeWithoutResponse si está disponible
  Future<bool> _sendRawCommand(String command) async {
    if (_writeCharacteristic == null) return false;
    
    try {
      List<int> bytes = utf8.encode(command + '\r\n');
      
      // Usar writeWithoutResponse si está disponible, sino write normal
      if (_writeCharacteristic!.properties.writeWithoutResponse) {
        await _writeCharacteristic!.write(bytes, withoutResponse: true);
      } else if (_writeCharacteristic!.properties.write) {
        await _writeCharacteristic!.write(bytes, withoutResponse: false);
      } else {
        debugPrint('❌ Characteristic does not support writing');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error sending raw command: $e');
      return false;
    }
  }

  // Disconnect from current device
  Future<void> disconnect() async {
    try {
      await _scanSubscription?.cancel();
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      _connectedDevice = null;
      _writeCharacteristic = null;
      _isConnected = false;
      debugPrint('Disconnected from printer');
    } catch (e) {
      debugPrint('Error disconnecting: $e');
      _connectedDevice = null;
      _writeCharacteristic = null;
      _isConnected = false;
    }
  }

  // MÉTODO PRINCIPAL DE IMPRESIÓN - CORREGIDO PARA ZQ310
  Future<bool> printZPL(String zplContent) async {
    if (!_isConnected || _connectedDevice == null || _writeCharacteristic == null) {
      throw Exception('No hay una impresora conectada');
    }

    try {
      debugPrint('=== PRINTING ZPL FOR ZQ310 ===');
      debugPrint('ZPL Content: $zplContent');
      
      // Asegurar que el ZPL termine correctamente
      if (!zplContent.endsWith('^XZ')) {
        zplContent += '^XZ';
      }
      
      // NO modificar el ZPL automáticamente - puede causar problemas
      
      List<int> bytes = utf8.encode(zplContent);
      debugPrint('Total bytes to send: ${bytes.length}');
      
      // MÉTODO CORREGIDO: Determinar si usar writeWithoutResponse o write
      bool useWithoutResponse = _writeCharacteristic!.properties.writeWithoutResponse;
      bool canWrite = _writeCharacteristic!.properties.write;
      
      if (!useWithoutResponse && !canWrite) {
        throw Exception('La característica no soporta escritura');
      }
      
      // Usar chunks más pequeños para BLE
      const int chunkSize = 20;
      
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        List<int> chunk = bytes.sublist(i, end);
        
        // Usar el método apropiado según las propiedades de la característica
        if (useWithoutResponse) {
          await _writeCharacteristic!.write(chunk, withoutResponse: true);
        } else {
          await _writeCharacteristic!.write(chunk, withoutResponse: false);
        }
        
        // Delay para estabilidad
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      debugPrint('ZPL sent successfully');
      return true;
      
    } catch (e) {
      debugPrint('Error printing ZPL: $e');
      return false;
    }
  }

  // Test de impresión MUY SIMPLE
  Future<bool> printSimpleTest() async {
    if (!_isConnected || _connectedDevice == null) {
      throw Exception('No hay una impresora conectada');
    }

    try {
      debugPrint('=== ULTRA SIMPLE TEST ===');
      
      // El ZPL más simple posible
      String ultraSimpleZPL = '^XA^FO50,50^A0N,30,30^FDTEST^FS^XZ';
      
      return await printZPL(ultraSimpleZPL);
      
    } catch (e) {
      debugPrint('Error in simple test: $e');
      return false;
    }
  }

  // Test de impresión profesional CORREGIDO
  Future<bool> printTest() async {
    if (!_isConnected || _connectedDevice == null) {
      throw Exception('No hay una impresora conectada');
    }

    try {
      debugPrint('=== STARTING PROFESSIONAL ZPL TEST ===');
      
      // ZPL más simple y confiable para ZQ310
      String professionalZPL = '''^XA
^CF0,30
^FO50,50^FDSIDCOP MOBILE^FS
^CF0,20
^FO50,80^FDSistema de Ventas^FS
^FO50,110^FDHonduras, CA^FS
^FO50,140^GB300,2,2^FS
^CF0,18
^FO50,160^FDPRUEBA DE IMPRESORA^FS
^FO50,180^FDDispositivo: ${_connectedDevice?.platformName ?? 'ZQ310'}^FS
^FO50,200^FDFecha: ${DateTime.now().toString().split(' ')[0]}^FS
^FO50,220^FDHora: ${DateTime.now().toString().split(' ')[1].split('.')[0]}^FS
^FO50,250^GB300,2,2^FS
^CF0,25
^FO50,270^FDESTADO: OK^FS
^XZ''';

      bool success = await printZPL(professionalZPL);
      
      if (success) {
        debugPrint('✅ Professional test print sent successfully');
        await Future.delayed(const Duration(seconds: 2));
      }
      
      return success;
      
    } catch (e) {
      debugPrint('Error in professional test print: $e');
      return false;
    }
  }

  // Print invoice optimizado
  Future<bool> printInvoice(Map<String, dynamic> invoiceData) async {
    try {
      if (!_isConnected) {
        throw Exception('Impresora no conectada');
      }

      final zplContent = _generateInvoiceZPL(invoiceData);
      return await printZPL(zplContent);
      
    } catch (e) {
      debugPrint('Error printing invoice: $e');
      rethrow;
    }
  }

  String _generateInvoiceZPL(Map<String, dynamic> invoiceData) {
  // Extraer información de la empresa
  final empresaNombre = invoiceData['coFa_NombreEmpresa'] ?? 'SIDCOP';
  final empresaDireccion = invoiceData['coFa_DireccionEmpresa'] ?? '';
  final empresaRTN = invoiceData['coFa_RTN'] ?? '';
  final empresaTelefono = invoiceData['coFa_Telefono1'] ?? '';
  final empresaCorreo = invoiceData['coFa_Correo'] ?? '';
  
  // Información de la factura
  final factNumero = invoiceData['fact_Numero'] ?? 'F001-0000001';
  final factTipo = invoiceData['fact_TipoVenta'] ?? 'EFECTIVO';
  final factFecha = _formatDate(invoiceData['fact_FechaEmision']);
  final factHora = _formatTime(invoiceData['fact_FechaEmision']);
  final cai = invoiceData['regC_Descripcion'] ?? '';
  final tipoDocumento = invoiceData['fact_TipoDeDocumento'] ?? 'FAC';
  
  // Información del cliente
  final clienteNombre = invoiceData['cliente'] ?? 'Cliente General';
  final clienteRTN = invoiceData['clie_RTN'] ?? '';
  final clienteTelefono = invoiceData['clie_Telefono'] ?? '';
  final clienteDireccion = invoiceData['diCl_DireccionExacta'] ?? '';
  
  // Información del vendedor y sucursal
  final vendedorNombre = invoiceData['vendedor'] ?? '';
  final sucursalNombre = invoiceData['sucu_Descripcion'] ?? '';
  
  // Totales con más detalle
  final subtotal = (invoiceData['fact_Subtotal'] ?? 0).toStringAsFixed(2);
  final impuesto15 = (invoiceData['fact_TotalImpuesto15'] ?? 0).toStringAsFixed(2);
  final impuesto18 = (invoiceData['fact_TotalImpuesto18'] ?? 0).toStringAsFixed(2);
  final descuento = (invoiceData['fact_TotalDescuento'] ?? 0).toStringAsFixed(2);
  final total = (invoiceData['fact_Total'] ?? 0).toStringAsFixed(2);
  final importeExento = (invoiceData['fact_ImporteExento'] ?? 0).toStringAsFixed(2);
  final importeGravado15 = (invoiceData['fact_ImporteGravado15'] ?? 0).toStringAsFixed(2);
  final importeGravado18 = (invoiceData['fact_ImporteGravado18'] ?? 0).toStringAsFixed(2);
  
  // Productos (mostrar hasta 6 productos para mejor visualización)
  final detalles = invoiceData['detalleFactura'] as List<dynamic>? ?? [];
  
  String productosZPL = '';
  int yPosition = 420;
  int itemCount = 0;
  
  for (var detalle in detalles.take(6)) {
    if (itemCount >= 6) break;
    
    final producto = detalle['prod_Descripcion'] ?? 'Producto';
    final codigoProducto = detalle['prod_CodigoBarra'] ?? '';
    final cantidad = detalle['faDe_Cantidad']?.toString() ?? '1';
    final precio = (detalle['faDe_PrecioUnitario'] ?? 0).toStringAsFixed(2);
    final totalItem = (detalle['faDe_Total'] ?? 0).toStringAsFixed(2);
    
    // Truncar nombre del producto si es muy largo (para etiqueta)
    final productoCorto = producto.length > 25 ? producto.substring(0, 25) + '...' : producto;
    
    // Producto principal
    productosZPL += '^FO20,$yPosition^A0N,16,16^FD$productoCorto^FS';
    productosZPL += '^FO220,$yPosition^A0N,16,16^FD$cantidad^FS';
    productosZPL += '^FO270,$yPosition^A0N,16,16^FDL$precio^FS';
    productosZPL += '^FO330,$yPosition^A0N,16,16^FDL$totalItem^FS';
    
    // Código de producto (más pequeño, debajo)
    if (codigoProducto.isNotEmpty) {
      yPosition += 22;
      productosZPL += '^FO20,$yPosition^A0N,12,12^FDCod: $codigoProducto^FS';
      yPosition += 18;
    } else {
      yPosition += 25;
    }
    
    itemCount++;
  }
  
  // Si hay más productos, mostrar indicador
  String masProductos = '';
  if (detalles.length > 6) {
    masProductos = '^FO20,$yPosition^A0N,14,14^FD... y ${detalles.length - 6} productos adicionales^FS';
    yPosition += 25;
  }

  // Calcular posición para totales
  final totalesY = yPosition + 30;
  
  // Generar sección de totales dinámicamente
  String totalesZPL = '';
  int totalY = totalesY;
  
  // Subtotal
  totalesZPL += '^FO200,$totalY^A0N,18,18^FDSubtotal:^FS';
  totalesZPL += '^FO330,$totalY^A0N,18,18^FDL$subtotal^FS';
  totalY += 25;
  
  // Importe Exento (si aplica)
  if (double.parse(importeExento) > 0) {
    totalesZPL += '^FO200,$totalY^A0N,16,16^FDImporte Exento:^FS';
    totalesZPL += '^FO330,$totalY^A0N,16,16^FDL$importeExento^FS';
    totalY += 22;
  }
  
  // Importe Gravado 15% (si aplica)
  if (double.parse(importeGravado15) > 0) {
    totalesZPL += '^FO200,$totalY^A0N,16,16^FDGravado 15%:^FS';
    totalesZPL += '^FO330,$totalY^A0N,16,16^FDL$importeGravado15^FS';
    totalY += 22;
  }
  
  // Importe Gravado 18% (si aplica)
  if (double.parse(importeGravado18) > 0) {
    totalesZPL += '^FO200,$totalY^A0N,16,16^FDGravado 18%:^FS';
    totalesZPL += '^FO330,$totalY^A0N,16,16^FDL$importeGravado18^FS';
    totalY += 22;
  }
  
  // Descuento (si aplica)
  if (double.parse(descuento) > 0) {
    totalesZPL += '^FO200,$totalY^A0N,16,16^FDDescuento:^FS';
    totalesZPL += '^FO330,$totalY^A0N,16,16^FD-L$descuento^FS';
    totalY += 22;
  }
  
  // ISV 15% (si aplica)
  if (double.parse(impuesto15) > 0) {
    totalesZPL += '^FO200,$totalY^A0N,16,16^FDISV 15%:^FS';
    totalesZPL += '^FO330,$totalY^A0N,16,16^FDL$impuesto15^FS';
    totalY += 22;
  }
  
  // ISV 18% (si aplica)
  if (double.parse(impuesto18) > 0) {
    totalesZPL += '^FO200,$totalY^A0N,16,16^FDISV 18%:^FS';
    totalesZPL += '^FO330,$totalY^A0N,16,16^FDL$impuesto18^FS';
    totalY += 22;
  }
  
  // Línea divisoria antes del total
  totalesZPL += '^FO200,${totalY + 5}^GB180,2,2^FS';
  totalY += 15;
  
  // Total final (más grande y destacado)
  totalesZPL += '^FO200,$totalY^A0N,22,22^FDTOTAL:^FS';
  totalesZPL += '^FO330,$totalY^A0N,22,22^FDL$total^FS';
  totalY += 35;

  // Calcular posición final para footer
  final footerY = totalY + 20;

  return '''^XA

^FX ===== HEADER EMPRESA (CENTRADO Y MAS GRANDE) =====
^FO20,30^GB360,3,3^FS
^CF0,24
^FO30,45^FD$empresaNombre^FS
^CF0,16
^FO30,75^FD$empresaDireccion^FS
^FO30,95^FDCasa Matriz^FS
^CF0,14
^FO30,115^FDTel: $empresaTelefono^FS
^FO30,135^FDEmail: $empresaCorreo^FS
^FO30,155^FDRTN: $empresaRTN^FS
^FO20,175^GB360,3,3^FS

^FX ===== TITULO FACTURA (CENTRADO) =====
^CF0,20
^FO160,195^FD$tipoDocumento^FS
^CF0,18
^FO120,220^FD$factNumero^FS

^FX ===== INFORMACION DE FACTURA =====
^CF0,16
^FO20,250^FDCAI: $cai^FS
^FO20,270^FDFecha: $factFecha^FS
^FO20,290^FDHora: $factHora^FS
^FO200,270^FDTipo: $factTipo^FS
^FO200,290^FDSucursal: $sucursalNombre^FS

^FX ===== INFORMACION CLIENTE =====
^FO20,320^GB360,2,2^FS
^CF0,16
^FO20,335^FDCliente: $clienteNombre^FS
^CF0,14
^FO20,355^FDRTN: $clienteRTN Tel: $clienteTelefono^FS
^FO20,375^FDDireccion: $clienteDireccion^FS

^FX ===== TABLA PRODUCTOS =====
^FO20,395^GB360,2,2^FS
^CF0,16
^FO20,405^FDProducto^FS
^FO220,405^FDCant^FS
^FO270,405^FDPrecio^FS
^FO330,405^FDTotal^FS
^FO20,420^GB360,1,1^FS

^FX ===== PRODUCTOS =====
$productosZPL
$masProductos

^FX ===== TOTALES =====
^FO20,$totalesY^GB360,2,2^FS
$totalesZPL

^FX ===== FOOTER =====
^FO20,$footerY^GB360,2,2^FS
^CF0,14
^FO20,${footerY + 15}^FDVendedor: $vendedorNombre^FS
^CF0,16
^FO120,${footerY + 40}^FDGracias por su compra!^FS
^CF0,12
^FO140,${footerY + 60}^FDSIDCOP - Sistema POS^FS
^FO100,${footerY + 75}^FD${DateTime.now().toIso8601String().split('T')[0]}^FS

^XZ''';
}
  
  // Helper para formatear fecha
  String _formatDate(String? isoDate) {
    if (isoDate == null) return DateTime.now().toString().split(' ')[0];
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return DateTime.now().toString().split(' ')[0];
    }
  }
  
  // Helper para formatear hora
  String _formatTime(String? isoDate) {
    if (isoDate == null) return DateTime.now().toString().split(' ')[1].split('.')[0];
    try {
      final date = DateTime.parse(isoDate);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return DateTime.now().toString().split(' ')[1].split('.')[0];
    }
  }

  // Método para diagnosticar problemas de conexión
  Future<Map<String, dynamic>> diagnoseConnection() async {
    Map<String, dynamic> diagnosis = {
      'isConnected': _isConnected,
      'hasDevice': _connectedDevice != null,
      'hasCharacteristic': _writeCharacteristic != null,
      'deviceName': _connectedDevice?.platformName ?? 'N/A',
      'deviceId': _connectedDevice?.remoteId.toString() ?? 'N/A',
      'characteristicUuid': _writeCharacteristic?.uuid.toString() ?? 'N/A',
      'canWrite': false,
      'canWriteWithoutResponse': false,
    };

    if (_writeCharacteristic != null) {
      diagnosis['canWrite'] = _writeCharacteristic!.properties.write;
      diagnosis['canWriteWithoutResponse'] = _writeCharacteristic!.properties.writeWithoutResponse;
    }

    // Test de comunicación básico
    if (_isConnected && _writeCharacteristic != null) {
      try {
        await _sendRawCommand('~HS'); // Status command
        diagnosis['communicationTest'] = 'SUCCESS';
      } catch (e) {
        diagnosis['communicationTest'] = 'FAILED: $e';
      }
    }

    debugPrint('Connection Diagnosis: $diagnosis');
    return diagnosis;
  }

  // Método para mostrar diálogo de selección de impresora
  Future<BluetoothDevice?> showPrinterSelectionDialog(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Buscando impresoras Zebra...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Escaneando dispositivos Bluetooth'),
            ],
          ),
        ),
      );

      final devices = await startScan();
      Navigator.of(context).pop();
      
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron dispositivos Bluetooth.'),
            backgroundColor: Colors.orange,
          ),
        );
        return null;
      }

      return await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seleccionar Impresora Zebra'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final isPrinter = _isPotentialPrinter(device.platformName);
                
                return Card(
                  color: isPrinter ? Colors.blue.shade50 : Colors.grey.shade100,
                  child: ListTile(
                    leading: Icon(
                      isPrinter ? Icons.print : Icons.bluetooth,
                      color: isPrinter ? Colors.blue : Colors.grey,
                    ),
                    title: Text(
                      device.platformName.isNotEmpty ? device.platformName : 'Dispositivo sin nombre',
                      style: TextStyle(
                        fontWeight: isPrinter ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${device.remoteId}'),
                        if (isPrinter) 
                          const Text('✓ Posible impresora Zebra', 
                                   style: TextStyle(color: Colors.green)),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(device),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    disconnect().catchError((e) => debugPrint('Error in dispose: $e'));
  }
}