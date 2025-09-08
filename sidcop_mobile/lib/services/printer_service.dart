import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/numero_en_letras.dart';
import '../models/PedidosViewModel.Dart';

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
  static const String ZEBRA_SERVICE_UUID =
      "38eb4a80-c570-11e3-9507-0002a5d5c51b";
  // CAMBIO PRINCIPAL: Usar la característica que SÍ es escribible
  static const String ZEBRA_WRITE_UUID = "38eb4a82-c570-11e3-9507-0002a5d5c51b";

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

      return statuses.values.every(
        (status) => status.isGranted || status.isLimited,
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
      _devices = systemDevices
          .where((device) => device.platformName.isNotEmpty)
          .toList();

      await _scanSubscription?.cancel();

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

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
        mtu: null, // Usar MTU por defecto
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
        throw Exception(
          'No se encontró característica de escritura compatible con Zebra',
        );
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
  Future<BluetoothCharacteristic?> _findZebraWriteCharacteristic(
    List<BluetoothService> services,
  ) async {
    BluetoothCharacteristic? zebraChar;
    BluetoothCharacteristic? fallbackChar;

    // Examinar TODOS los servicios y características
    for (BluetoothService service in services) {
      String serviceUuid = service.uuid.toString().toLowerCase();
      debugPrint('Service: $serviceUuid');

      bool isZebraService =
          serviceUuid.contains('38eb4a80') || serviceUuid.contains('c570-11e3');
      if (isZebraService) {
        debugPrint('>>> ZEBRA SERVICE FOUND <<<');
      }

      for (BluetoothCharacteristic char in service.characteristics) {
        String charUuid = char.uuid.toString().toLowerCase();
        debugPrint('  Characteristic: $charUuid');
        debugPrint(
          '    Properties: write=${char.properties.write}, writeWithoutResponse=${char.properties.writeWithoutResponse}, notify=${char.properties.notify}, indicate=${char.properties.indicate}',
        );

        // PRIORIDAD 1: Zebra 38eb4a82 (la que SÍ es escribible)
        if (isZebraService &&
            charUuid.contains('38eb4a82') &&
            char.properties.write) {
          debugPrint(
            '  >>> ZEBRA WRITABLE CHARACTERISTIC FOUND (38eb4a82) <<<',
          );
          zebraChar = char;
          break; // Esta es la que queremos
        }

        // PRIORIDAD 2: Zebra 38eb4a84 si tiene write
        if (isZebraService &&
            charUuid.contains('38eb4a84') &&
            char.properties.write) {
          debugPrint(
            '  >>> ZEBRA ALTERNATIVE WRITABLE CHARACTERISTIC FOUND (38eb4a84) <<<',
          );
          if (zebraChar == null) zebraChar = char;
        }

        // Fallback: Cualquier característica escribible
        if ((char.properties.writeWithoutResponse || char.properties.write) &&
            fallbackChar == null) {
          debugPrint('    >>> WRITABLE CHARACTERISTIC FOUND (fallback) <<<');
          fallbackChar = char;
        }
      }

      // Si ya encontramos la característica Zebra correcta, salir del loop
      if (zebraChar != null &&
          zebraChar.uuid.toString().toLowerCase().contains('38eb4a82')) {
        break;
      }
    }

    // Prioridad: Zebra específica > Fallback writable
    if (zebraChar != null) {
      debugPrint('Using Zebra characteristic: ${zebraChar.uuid}');
      return zebraChar;
    } else if (fallbackChar != null) {
      debugPrint(
        'Using fallback writable characteristic: ${fallbackChar.uuid}',
      );
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
    if (!_isConnected ||
        _connectedDevice == null ||
        _writeCharacteristic == null) {
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
      bool useWithoutResponse =
          _writeCharacteristic!.properties.writeWithoutResponse;
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
      String professionalZPL =
          '''^XA
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

  Future<bool> printInventory(Map<String, dynamic> inventoryData) async {
  try {
    if (!_isConnected) {
      throw Exception('Impresora no conectada');
    }

    final zplContent = _generateInventoryZPL(inventoryData);
    return await printZPL(zplContent);
  } catch (e) {
    debugPrint('Error printing inventory: $e');
    rethrow;
  }
}

  Future<bool> printPedido(PedidosViewModel pedido) async {
    try {
      if (!_isConnected) {
        throw Exception('Impresora no conectada');
      }

      final zplContent = _generatePedidoZPL(pedido);
      return await printZPL(zplContent);
    } catch (e) {
      debugPrint('Error printing pedido: $e');
      rethrow;
    }
  }

  String _generatePedidoZPL(PedidosViewModel pedido) {
    final empresaNombre = pedido.coFaNombreEmpresa ?? 'Nombre de Empresa no disponible';
    final now = DateTime.now();
    final fecha = _formatDate(now.toString());
    final direccion = pedido.coFaDireccionEmpresa ?? 'Dirección no disponible';
    final telefono = pedido.coFaTelefono1 ?? 'N/A';
    final correo = pedido.coFaCorreo ?? 'N/A';

    final pedidoCodigo = pedido.pedi_Codigo ?? 'N/A';
    final clienteNombre = pedido.clieNombreNegocio ?? '${pedido.clieNombres ?? ''} ${pedido.clieApellidos ?? ''}';
    final clienteRTN = pedido.prodDescripcion ?? 'N/A';
    final vendedorNombre = '${pedido.vendNombres ?? ''} ${pedido.vendApellidos ?? ''}';
    final fechaPedido = _formatDate(pedido.pediFechaPedido.toString());

    final detalles = jsonDecode(pedido.detallesJson ?? '[]') as List<dynamic>;
    String productosZPL = '';
    int yPosition = 620;
    double totalPedido = 0;

        for (var detalle in detalles) {
      final producto = detalle['descripcion']?.toString() ?? 'Sin producto';
      final cantidad = _getIntValue(detalle, 'cantidad');
      final precio = _getDoubleValue(detalle, 'precio');
      final totalItem = cantidad * precio;
      totalPedido += totalItem;

      final productoLimpio = _cleanSpecialCharacters(producto);
      final precioStr = 'L.' + precio.toStringAsFixed(2);
      final totalItemStr = 'L.' + totalItem.toStringAsFixed(2);

      productosZPL += '^FO0,${yPosition}^FB170,3,0,L,0^FD$productoLimpio^FS\n';
      productosZPL += '^FO175,${yPosition}^FB35,1,0,R,0^FD$cantidad^FS\n';
      productosZPL += '^FO215,${yPosition}^FB80,1,0,R,0^FD$precioStr^FS\n';
      productosZPL += '^FO300,${yPosition}^FB85,1,0,R,0^FD$totalItemStr^FS\n';

      // Adjusted for a font width of ~14 chars per line with FB width of 170
      int lineasProducto = (productoLimpio.length / 14).ceil();
      if (lineasProducto < 1) lineasProducto = 1;
      yPosition += (lineasProducto * 25) + 20;
    }

    final totalPedidoStr = totalPedido.toStringAsFixed(2);

    final alturaTotal = yPosition + 350;

    const String logoZPL = ''''^FX ===== LOGO CENTRADO =====
^FO130,60
^GFA,1950,1666,17,
,::::::M07U018O0M0EU01EO0L01EV0FO00000807EV0F802L00001807CV0FC06L00001C0FCV07E07L00003C1FCV07E07L00003C1F8V03F0FL00003E3FW03F0F8K00003E3F0001F8Q01F8F8K00003E3E00071CR0F8F8K00007E3C000E0CR078F8K00007E21801E0CQ0318F8K00003E07001ES03C0F8K00003E0F003ES01E0F8K00003E3F003ES01F0F8K00043C3E007CS01F8F0800000061C7E007CT0FC70C000000618FE007CT0FE21C000000F00FC007CT07E01C000000F81F80078T07E03C000000F81F80078T03F03C000000F81F000F8T01F07C000000FC1E000FV0F07C000000FC12000FV0907C0000007C06000EV0C0FC0000007C0E001EV0E0FC0000007C1E001C0000FFFF8M0F0F80000003C3C00380007F7FFEM0F8F80000003C7C0070001E03C1FM0FC7K0001CFC00FE003807C078L07C7040000608FC01FFC06007C078L07E60C0000701F80787E0C0078078L07E01C0000781F80F01F180078078L03F03C00007C1F00E00F980078078L03F07C00007E1F004007F000F00FM01F0F800007E1E200003F060F01EL010F1F800003F1C6K0F8F0F03CL01871F800003F00EK079F0FFF8L01C13F000001F80EK03FE1EFEM01E03F000001F81EL0FC1E3CM01F03E000000F83EN01C3CM01F07E000000783EN03C1EM01F87C000000383EN03C1EM01F83K01C087EN0381EN0F82070000F007EN0780FN0FC03E0000FC07CN0780FN0FC0FE00007F07CN0700F8M07C1FC00007F8784M0F0078L047C3F800003FC78CM0E0078L063C7F800001FE71CM0E003CL071CFF000000FE43CM0C003EL0708FE0000007E03CP01EL0F81F80000001F03CP01FL0F81FK0K07CQ0F8K0F81L0070007C2P07800C10FC003C00003F007C3P03C00C18FC01F800003FC07C7P01E00C187C0FF000001FF0FC7Q0F81C3C7C1FF000000FF87C78P07E383C7C3FE0000007FC78F8P01FE03C7C7FC0000003FC78F8T03E3CFFK0000FE70F88R043E18FEK00003E20F8CR047E08F8K0M0F8ER0E7EO0M0F8FQ01E7EO0000FE00F8FQ03E3E01FEK0000FFC0F8F8P03E3E0FFCK00007FF0F0F8P07E3C1FF8K00003FF870FCP07E1C3FFL00000FFC60FCP07C087FEL000003FC007C6M01CFC00FF8L0K0FC007C7CL0F8FC00FEM0O07E3FK03F8F8Q0L03C03C3FC00007F0F80F8N0K0FFF83C1FE0001FE0F07FFCM0K07FFE1C0FF0003FE060FFFCM0K03FFF0C07F8003FC041FFF8M0L0FFF0003F8007F8001FFEN0L01FC0000FC007E00007FO0P0E003C007801ER0O0FFCN07FEQ0N03FFE00038000FFF8P0N0FFFC00078000FFFEP0M01FFF80F0781E03FFFP0N07FE0FFC38FFC0FF8P0Q03FFE00FFFT0Q0FFFC007FFCS0P01FFF0003FFFS0Q07FC0000FFCS0,
^FS''';

    return ''''^XA
^LL$alturaTotal
^LH0,0
^CI28

$logoZPL

^FO0,190^FB384,1,0,C,0^CF0,28^FD$empresaNombre^FS
^FO0,225^FB384,3,0,C,0^CF0,22^FD$direccion^FS
^FO0,285^FB384,1,0,C,0^CF0,22^FDTel: $telefono^FS
^FO0,310^FB384,1,0,C,0^CF0,22^FD$correo^FS

^FO0,350^CF0,22^FDCAI: 35ABDF-AB7210-9748E0-63BE03-090965^FS
^FO0,375^CF0,22^FDNo. Factura: $pedidoCodigo^FS
^FO0,400^CF0,22^FDFecha Emision: $fechaPedido^FS
^FO0,425^CF0,22^FDTipo Venta: CONTADO^FS

^FO0,450^CF0,22^FDCliente: $clienteNombre^FS
^FO0,475^CF0,22^FDRTN cliente: $clienteRTN^FS
^FO0,500^CF0,22^FDVendedor: $vendedorNombre^FS

^FX --- Column Headers ---
^FX Producto: x=0, Cant: x=175, Precio: x=215, Monto: x=300
^FO0,600^CF0,22^FDProd^FS
^FO175,600^CF0,22^FDCant^FS
^FO215,600^CF0,22^FDPrecio^FS
^FO300,600^CF0,22^FDMonto^FS
^FO0,620^GB384,1,1^FS

$productosZPL

^FO0,${yPosition}^GB384,2,2^FS

^FO0,${yPosition + 20}^CF0,22^FDSubtotal: L. $totalPedidoStr^FS
^FO0,${yPosition + 45}^CF0,22^FDTotalDescuento: L. 0.00^FS
^FO0,${yPosition + 70}^CF0,22^FDImporte Exento: L. 0.00^FS
^FO0,${yPosition + 95}^CF0,22^FDImporte Exonerado: L. 0.00^FS
^FO0,${yPosition + 120}^CF0,22^FDImporte Gravado 15%: L. 0.00^FS
^FO0,${yPosition + 145}^CF0,22^FDImporte Gravado 18%: L. 0.00^FS
^FO0,${yPosition + 170}^CF0,22^FDTotal Impuesto 15%: L. 0.00^FS
^FO0,${yPosition + 195}^CF0,22^FDTotal Impuesto 18%: L. 0.00^FS
^FO0,${yPosition + 220}^GB384,1,1^FS
^FO0,${yPosition + 235}^CF0,25^FDTotal: L. $totalPedidoStr^FS

^FO0,${yPosition + 270}^CF0,22^FDVendedor: $vendedorNombre^FS
^FO0,${yPosition + 300}^FB384,1,0,C,0^CF0,22^FDGracias por su compra^FS
^FO0,${yPosition + 325}^FB384,1,0,C,0^CF0,22^FDSIDCOP - Sistema POS^FS
^FO0,${yPosition + 350}^FB384,1,0,C,0^CF0,22^FD$fecha^FS

^XZ''';
  }

String _generateInventoryZPL(Map<String, dynamic> inventoryData) {
  // Extraer información del header
  final header = inventoryData['header'] as Map<String, dynamic>? ?? {};
  final rutaDescripcion = header['rutaDescripcion'] ?? 'Sin ruta';
  final vendedor = header['vendedor'] ?? 'Sin vendedor';
  
  // Extraer detalle de productos
  final detalles = inventoryData['detalle'] as List<dynamic>? ?? [];
  
  // Información fija de la empresa (puedes parametrizarla si es necesaria)
  const String empresaNombre = 'Comercial La Roca S. De R.L.';
  
  // Fecha y hora actual
  final now = DateTime.now();
  final fecha = _formatDate(now.toString());
  final hora = _formatTime(now.toString());

  // Generar ZPL para productos
  String productosZPL = '';
  int yPosition = 400; // Posición inicial de productos

  // Procesar productos
  for (var detalle in detalles) {
    final producto = detalle['producto']?.toString() ?? 'Sin producto';
    final codigo = detalle['codigo']?.toString() ?? '';
    final inicial = _getIntValue(detalle, 'inicial');
    final final_ = _getIntValue(detalle, 'final');
    final vendido = _getIntValue(detalle, 'vendido');

    // Limpiar caracteres especiales del producto
    final productoLimpio = _cleanSpecialCharacters(producto);

    // Producto (nombre con múltiples líneas) - Columna más ancha
    productosZPL += '^FO0,$yPosition^CI28^CF0,20,22^FB200,3,0,L,0^FD$productoLimpio^FS\n';
    
    // Cantidades alineadas a la primera línea del producto
    productosZPL += '^FO210,$yPosition^CF0,20,22^A0N,20,22^FD$inicial^FS\n';  // Inicial
    productosZPL += '^FO260,$yPosition^CF0,20,22^A0N,20,22^FD$vendido^FS\n';  // Vendido
    productosZPL += '^FO310,$yPosition^CF0,20,22^A0N,20,22^FD$final_^FS\n';   // Final

    // Calcular espacio necesario
    int lineasProducto = (productoLimpio.length / 24).ceil(); // ~24 caracteres por línea
    if (lineasProducto > 3) lineasProducto = 3; // Máximo 3 líneas
    if (lineasProducto < 1) lineasProducto = 1; // Mínimo 1 línea
    
    yPosition += (lineasProducto * 22) + 24; // Espacio del nombre + código
    yPosition += 15; // Espacio entre productos
  }

  // Calcular altura total sin sección de totales
  final alturaTotal = yPosition + 150;

  // Limpiar caracteres especiales de los campos del header
  final empresaLimpia = _cleanSpecialCharacters(empresaNombre);
  final rutaLimpia = _cleanSpecialCharacters(rutaDescripcion);
  final vendedorLimpio = _cleanSpecialCharacters(vendedor);

  // Logo GFA (el mismo que usas en facturas)
  const String logoZPL = '''^FX ===== LOGO CENTRADO =====
^FO130,60
^GFA,1950,1666,17,
,::::::M07U018O0M0EU01EO0L01EV0FO00000807EV0F802L00001807CV0FC06L00001C0FCV07E07L00003C1FCV07E07L00003C1F8V03F0FL00003E3FW03F0F8K00003E3F0001F8Q01F8F8K00003E3E00071CR0F8F8K00007E3C000E0CR078F8K00007E21801E0CQ0318F8K00003E07001ES03C0F8K00003E0F003ES01E0F8K00003E3F003ES01F0F8K00043C3E007CS01F8F0800000061C7E007CT0FC70C000000618FE007CT0FE21C000000F00FC007CT07E01C000000F81F80078T07E03C000000F81F80078T03F03C000000F81F000F8T01F07C000000FC1E000FV0F07C000000FC12000FV0907C0000007C06000EV0C0FC0000007C0E001EV0E0FC0000007C1E001C0000FFFF8M0F0F80000003C3C00380007F7FFEM0F8F80000003C7C0070001E03C1FM0FC7K0001CFC00FE003807C078L07C7040000608FC01FFC06007C078L07E60C0000701F80787E0C0078078L07E01C0000781F80F01F180078078L03F03C00007C1F00E00F980078078L03F07C00007E1F004007F000F00FM01F0F800007E1E200003F060F01EL010F1F800003F1C6K0F8F0F03CL01871F800003F00EK079F0FFF8L01C13F000001F80EK03FE1EFEM01E03F000001F81EL0FC1E3CM01F03E000000F83EN01C3CM01F07E000000783EN03C1EM01F87C000000383EN03C1EM01F83K01C087EN0381EN0F82070000F007EN0780FN0FC03E0000FC07CN0780FN0FC0FE00007F07CN0700F8M07C1FC00007F8784M0F0078L047C3F800003FC78CM0E0078L063C7F800001FE71CM0E003CL071CFF000000FE43CM0C003EL0708FE0000007E03CP01EL0F81F80000001F03CP01FL0F81FK0K07CQ0F8K0F81L0070007C2P07800C10FC003C00003F007C3P03C00C18FC01F800003FC07C7P01E00C187C0FF000001FF0FC7Q0F81C3C7C1FF000000FF87C78P07E383C7C3FE0000007FC78F8P01FE03C7C7FC0000003FC78F8T03E3CFFK0000FE70F88R043E18FEK00003E20F8CR047E08F8K0M0F8ER0E7EO0M0F8FQ01E7EO0000FE00F8FQ03E3E01FEK0000FFC0F8F8P03E3E0FFCK00007FF0F0F8P07E3C1FF8K00003FF870FCP07E1C3FFL00000FFC60FCP07C087FEL000003FC007C6M01CFC00FF8L0K0FC007C7CL0F8FC00FEM0O07E3FK03F8F8Q0L03C03C3FC00007F0F80F8N0K0FFF83C1FE0001FE0F07FFCM0K07FFE1C0FF0003FE060FFFCM0K03FFF0C07F8003FC041FFF8M0L0FFF0003F8007F8001FFEN0L01FC0000FC007E00007FO0P0E003C007801ER0O0FFCN07FEQ0N03FFE00038000FFF8P0N0FFFC00078000FFFEP0M01FFF80F0781E03FFFP0N07FE0FFC38FFC0FF8P0Q03FFE00FFFT0Q0FFFC007FFCS0P01FFF0003FFFS0Q07FC0000FFCS0,
^FS''';

  return '''^XA
^LL$alturaTotal
^LH0,0

$logoZPL

^CI28

^FX ===== HEADER EMPRESA CENTRADO =====
^CF0,24,24
^FO0,190^FB360,1,0,C,0^FD$empresaLimpia^FS

^FO0,230^GB360,2,2^FS


^FX ===== INFORMACION =====
^CF0,20,22
^FO0,250^FB360,1,0,L,0^FD$rutaLimpia^FS
^FO0,275^FB360,1,0,L,0^FDVendedor: $vendedorLimpio^FS
^FO0,300^FB360,1,0,L,0^FDFecha: $fecha^FS
^FO0,325^FB360,1,0,L,0^FDHora: $hora^FS

^FX ===== TABLA PRODUCTOS (4 COLUMNAS) =====
^FO0,350^GB360,2,2^FS
^FO0,365^CF0,20,22^FDProducto^FS
^FO210,365^CF0,20,22^FDIni^FS
^FO260,365^CF0,20,22^FDFac^FS
^FO310,365^CF0,20,22^FDFin^FS
^FO0,385^GB360,1,1^FS

^FX ===== PRODUCTOS =====
$productosZPL

^XZ''';
}

// Función para limpiar caracteres especiales
String _cleanSpecialCharacters(String text) {
  // Mapa de caracteres especiales a caracteres básicos
  const Map<String, String> charMap = {
    // Vocales con acentos
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
    'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
    'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
    'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O', 'Ø': 'O',
    'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
    
    // Caracteres especiales del español
    'ñ': 'n', 'Ñ': 'N',
    'ç': 'c', 'Ç': 'C',
    
    // Otros caracteres problemáticos
    '°': 'o', '²': '2', '³': '3',
    '"': '"', '""': '"', ''': "'", ''': "'",
    '–': '-', '—': '-',
    '…': '...',
    
    // Símbolos de moneda (opcional, puedes mantener algunos)
    '¢': 'c', '£': 'L', '¥': 'Y', '€': 'E',
    
    // Fracciones comunes
    '½': '1/2', '¼': '1/4', '¾': '3/4',
  };

  String cleanText = text;
  
  charMap.forEach((special, replacement) {
    cleanText = cleanText.replaceAll(special, replacement);
  });
  
  return cleanText;
}

// Métodos auxiliares para manejo seguro de datos
int _getIntValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _getDoubleValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

  // Print invoice optimizado
  Future<bool> printInvoice(Map<String, dynamic> invoiceData, {bool isOriginal = true}) async {
    try {
      if (!_isConnected) {
        throw Exception('Impresora no conectada');
      }

      final zplContent = _generateInvoiceZPL(invoiceData, isOriginal: isOriginal);
      return await printZPL(zplContent);
    } catch (e) {
      debugPrint('Error printing invoice: $e');
      rethrow;
    }
  }

  String _generateInvoiceZPL(Map<String, dynamic> invoiceData, {bool isOriginal = true}) {
    // Extraer información de la empresa
    final empresaNombre = invoiceData['coFa_NombreEmpresa'] ?? 'SIDCOP';
    final empresaDireccion = invoiceData['coFa_DireccionEmpresa'] ?? 'Col. Satelite Norte, Bloque 3';
    final empresaRTN = invoiceData['coFa_RTN'] ?? '08019987654321';
    final empresaTelefono = invoiceData['coFa_Telefono1'] ?? '2234-5678';
    final empresaCorreo = invoiceData['coFa_Correo'] ?? 'info@sidcop.com';
    final empresaLogo = invoiceData['coFa_Logo'] ?? 'info@sidcop.com';

    // Información de la factura
    final factNumero = invoiceData['fact_Numero'] ?? 'F001-0000001';
  
    // Texto ORIGINAL o COPIA
    final tipoCopia = isOriginal ? 'ORIGINAL' : 'COPIA';
    final factTipoRaw = invoiceData['fact_TipoVenta'] ?? 'EFECTIVO';
    final factTipo = factTipoRaw == 'CO' ? 'CONTADO' : (factTipoRaw == 'CR' ? 'CREDITO' : factTipoRaw);
    final factFecha = _formatDate(invoiceData['fact_FechaEmision']);
    final factHora = _formatTime(invoiceData['fact_FechaEmision']);
    final cai = invoiceData['regC_Descripcion'] ?? 'ABC123-XYZ456-789DEF';
    final tipoDocumento = invoiceData['fact_TipoDeDocumento'] ?? 'FACTURA';

    // Información del cliente
    final clienteCodigo = invoiceData['clie_Id'] ?? '00000000';
    final clienteNombre = invoiceData['cliente'] ?? 'Cliente General';
    final clienteRTN = invoiceData['clie_RTN'] ?? '';
    final clienteTelefono = invoiceData['clie_Telefono'] ?? '';
    final clienteDireccion = invoiceData['diCl_DireccionExacta'] ?? '';

    final fechaLimiteEmision = _formatDate(invoiceData['regC_FechaFinalEmision']) ?? '31/12/2024';
    final desde = invoiceData['regC_RangoInicial'] ?? 'F001-00000001';
    final hasta = invoiceData['regC_RangoFinal'] ?? 'F001-99999999';
    final anulada = invoiceData['fact_Anulado'] == true || invoiceData['fact_Anulado'] == 1;

    // Información del vendedor y sucursal
    final vendedorNombre = invoiceData['vendedor'] ?? 'Vendedor';
    final sucursalNombre = invoiceData['sucu_Descripcion'] ?? 'Principal';

    // Totales con más detalle
    final subtotal = (invoiceData['fact_Subtotal'] ?? 0).toStringAsFixed(2);
    final impuesto15 = (invoiceData['fact_TotalImpuesto15'] ?? 0)
        .toStringAsFixed(2);
    final impuesto18 = (invoiceData['fact_TotalImpuesto18'] ?? 0)
        .toStringAsFixed(2);
    final descuento = (invoiceData['fact_TotalDescuento'] ?? 0).toStringAsFixed(
      2,
    );
    final total = (invoiceData['fact_Total'] ?? 0).toStringAsFixed(2);
    final importeExento = (invoiceData['fact_ImporteExento'] ?? 0)
        .toStringAsFixed(2);
        final importeExonerado = (invoiceData['fact_ImporteExonerado'] ?? 0)
        .toStringAsFixed(2);
    final importeGravado15 = (invoiceData['fact_ImporteGravado15'] ?? 0)
        .toStringAsFixed(2);
    final importeGravado18 = (invoiceData['fact_ImporteGravado18'] ?? 0)
        .toStringAsFixed(2);

    // Productos - MOSTRAR TODOS LOS PRODUCTOS
final detalles = invoiceData['detalleFactura'] as List<dynamic>? ?? [];

String productosZPL = '';
int yPosition = 870; // Posición inicial de productos

// Procesar TODOS los productos
for (var detalle in detalles) {
  final producto = detalle['prod_Descripcion'] ?? 'Producto';
  final codigoProducto = detalle['prod_CodigoBarra'] ?? '';
  final pagaImpuesto = detalle['prod_PagaImpuesto'] ?? 'NO';
  final cantidad = detalle['faDe_Cantidad']?.toString() ?? '1';
  final descuentoProducto = double.tryParse(detalle['faDe_Descuento']?.toString() ?? '0') ?? 0.0;
  final precioUnitario = (detalle['faDe_PrecioUnitario'] ?? 0).toStringAsFixed(2);
  final totalItem = (detalle['faDe_Subtotal'] ?? 0).toStringAsFixed(2);

  // Agregar asterisco si el producto no paga impuesto (pagaImpuesto == 'N')
  final asterisco = pagaImpuesto == 'N' ? ' *' : '';
  final productoConAsterisco = '$asterisco$producto';

  // Producto con múltiples líneas (máximo 5 líneas, ancho 160 dots para dejar espacio a las otras columnas)
  // Usando CF0,22,24 como el resto de la información de factura
  productosZPL += '^FO0,$yPosition^CF0,22,24^FB160,5,0,L,0^FD$productoConAsterisco^FS\n';
  
  // Cantidad, Precio y Monto alineados a la primera línea del producto
  productosZPL += '^FO165,$yPosition^CF0,22,24^FD$cantidad^FS\n';
  productosZPL += '^FO210,$yPosition^CF0,22,24^FDL$precioUnitario^FS\n';
  productosZPL += '^FO295,$yPosition^CF0,22,24^FDL$totalItem^FS\n';

  // Calcular espacio necesario para el producto (más preciso para ancho menor)
  int lineasProducto = (productoConAsterisco.length / 18).ceil(); // ~18 caracteres por línea con ancho 160 dots
  if (lineasProducto > 5) lineasProducto = 5; // Máximo 5 líneas
  if (lineasProducto < 1) lineasProducto = 1; // Mínimo 1 línea
  
  yPosition += (lineasProducto * 24); // 24 dots por línea para fuente 22,24

  

  // Mostrar descuento del producto si es mayor a cero
  if (descuentoProducto > 0) {
    yPosition += 6; // Pequeño espacio antes del descuento
    final descuentoFormateado = descuentoProducto.toStringAsFixed(2);
    productosZPL += '^FO10,$yPosition^FB350,1,0,R^CF0,22,24^FDDescuento: L$descuentoFormateado^FS\n';
    yPosition += 24; // Espacio del descuento
  }

  // Más espacio entre productos para mejor legibilidad
  yPosition += 50;
}

    // Calcular posición para totales dinámicamente
yPosition += 20; // Espacio antes de totales
final totalesY = yPosition;

// Generar sección de totales dinámicamente
String totalesZPL = '';
int totalY = totalesY + 15; // Posición inicial de totales

// Definir ancho del área de impresión (ajusta según tu etiqueta)
final int anchoEtiqueta = 360; // ancho en puntos
final int margenDerecho = 10;
final int anchoTexto = anchoEtiqueta - margenDerecho;

// MOSTRAR TODOS LOS CAMPOS alineados a la derecha
// Subtotal
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDSubtotal: L$subtotal^FS\n';
totalY += 25;

// Descuento (siempre mostrar)
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDTotal Descuento: L$descuento^FS\n';
totalY += 25;

// Importe Exento (siempre mostrar)
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDImporte Exento: L$importeExento^FS\n';
totalY += 25;

// Importe Exonerado (siempre mostrar)
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDImporte Exonerado: L$importeExonerado^FS\n';
totalY += 25;

// Gravado 15% (siempre mostrar)
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDImporte Gravado 15%: L$importeGravado15^FS\n';
totalY += 25;

// Gravado 18% (siempre mostrar)
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDImporte Gravado 18%: L$importeGravado18^FS\n';
totalY += 25;

// ISV 15% (siempre mostrar)
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDTotal Impuesto 15%: L$impuesto15^FS\n';
totalY += 25;

// ISV 18% (siempre mostrar)
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDTotal Impuesto 18%: L$impuesto18^FS\n';
totalY += 25;

// Línea divisoria antes del total (centrada o de extremo a extremo)
totalY += 5;
final lineaY = totalY;
totalesZPL += '^FO$margenDerecho,$lineaY^GB$anchoTexto,2,2^FS\n';
totalY += 10;

// Total final alineado a la derecha y destacado
totalesZPL += '^FO$margenDerecho,$totalY^FB$anchoTexto,1,0,R^CF0,22,24^FDTotal: L$total^FS\n';
totalY += 50;

// Total en letras (convertir el total a número, quitar el signo de L si existe)
final totalNum = double.tryParse(total.replaceAll('L', '')) ?? 0.0;
final totalEnLetras = ' ${NumeroEnLetras.convertir(totalNum)}';
totalesZPL += '^FO0,$totalY^FB$anchoEtiqueta,3,0,C,0^CF0,22,24^FD$totalEnLetras^FS\n';
totalY += 10; // Espacio adicional para el total en letras

    // Footer con posiciones dinámicas
    final footerY = totalY + 50; // Espacio antes del footer

    // Generar footer ZPL
    String footerZPL = '';
    int currentFooterY = footerY + 15;
    
     // Posición inicial dentro del footer

    footerZPL += '^FO0,$currentFooterY^FB$anchoEtiqueta,2,0,C,0^CF0,22,24^FD$tipoCopia^FS\n';
    currentFooterY += 45;

    // 1. FechaLimite Emision (1 línea, centrado)
    footerZPL += '^FO0,$currentFooterY^FB$anchoEtiqueta,2,0,C,0^CF0,22,24^FDFecha limite de emision: $fechaLimiteEmision^FS\n';
    currentFooterY += 45;

    // 2. Rango Autorizado (1 línea, centrado)
    footerZPL += '^FO0,$currentFooterY^FB$anchoEtiqueta,1,0,C,0^CF0,22,24^FDRango Autorizado:^FS\n';
    currentFooterY += 25;

    // 3. Desde (1 línea, centrado)
    footerZPL += '^FO0,$currentFooterY^FB$anchoEtiqueta,1,0,C,0^CF0,22,24^FDDesde: $desde^FS\n';
    currentFooterY += 25;

    // 4. Hasta (1 línea, centrado)
    footerZPL += '^FO0,$currentFooterY^FB$anchoEtiqueta,1,0,C,0^CF0,22,24^FDHasta: $hasta^FS\n';
    currentFooterY += 25;

    // 5. Espacio adicional antes del texto de copias
    currentFooterY += 10;

    // 6. Texto de copias (3 líneas máximo, centrado)
    footerZPL += '^FO0,$currentFooterY^FB$anchoEtiqueta,3,0,C,0^CF0,22,24^FDOriginal: Cliente, Copia 1: Obligado Tributario Emisor Copia 2: Archivo^FS\n';
    currentFooterY += 75; // Espacio para 3 líneas

    // 7. Espacio adicional antes del texto obligatorio
    currentFooterY += 10;

    // 8. Texto obligatorio en mayúsculas (centrado)
    footerZPL += '^FO0,$currentFooterY^FB$anchoEtiqueta,2,0,C,0^CF0,22,24^FDLA FACTURA ES BENEFICIO DE TODOS, ¡"EXIJALA"!^FS\n';
    currentFooterY += 50; // Espacio para 2 líneas

    // ===== NUEVA SECCIÓN: MARCA DE ANULADA =====
    if (anulada) {
      currentFooterY += 20; // Espacio adicional antes de la marca ANULADA

      // Definir dimensiones del recuadro
      final int anchoRecuadro = 250; // Ancho del recuadro
      final int altoRecuadro = 80;   // Alto del recuadro
      final int xRecuadro = (anchoEtiqueta - anchoRecuadro) ~/ 2; // Centrar horizontalmente
      final int yRecuadro = currentFooterY;

      // 1. Recuadro exterior (línea gruesa)
      footerZPL += '^FO$xRecuadro,$yRecuadro^GB$anchoRecuadro,$altoRecuadro,4^FS\n';

      // 2. Recuadro interior (línea delgada, para efecto de doble borde)
      final int xInterior = xRecuadro + 8;
      final int yInterior = yRecuadro + 8;
      final int anchoInterior = anchoRecuadro - 16;
      final int altoInterior = altoRecuadro - 16;
      footerZPL += '^FO$xInterior,$yInterior^GB$anchoInterior,$altoInterior,2^FS\n';

      // 3. Texto "A N U L A D A" centrado en el recuadro
      final int yTextoAnulada = yRecuadro + 25; // Centrar verticalmente en el recuadro
      footerZPL += '^FO$xRecuadro,$yTextoAnulada^FB$anchoRecuadro,1,0,C,0^CF0,28,32^FDA N U L A D A^FS\n';

      currentFooterY += altoRecuadro + 20; // Actualizar posición después del recuadro
    }

    // 9. Espacio adicional antes del identificador de copia
    if (!anulada) {
      currentFooterY += 10;
    }

  
    final alturaTotal = currentFooterY + (anulada ? 100 : 50);


    // Logo GFA (formato correcto y completo)
    const String logoZPL = '''^FX ===== LOGO CENTRADO =====
^FO130,60
^GFA,1950,1666,17,
,::::::M07U018O0M0EU01EO0L01EV0FO00000807EV0F802L00001807CV0FC06L00001C0FCV07E07L00003C1FCV07E07L00003C1F8V03F0FL00003E3FW03F0F8K00003E3F0001F8Q01F8F8K00003E3E00071CR0F8F8K00007E3C000E0CR078F8K00007E21801E0CQ0318F8K00003E07001ES03C0F8K00003E0F003ES01E0F8K00003E3F003ES01F0F8K00043C3E007CS01F8F0800000061C7E007CT0FC70C000000618FE007CT0FE21C000000F00FC007CT07E01C000000F81F80078T07E03C000000F81F80078T03F03C000000F81F000F8T01F07C000000FC1E000FV0F07C000000FC12000FV0907C0000007C06000EV0C0FC0000007C0E001EV0E0FC0000007C1E001C0000FFFF8M0F0F80000003C3C00380007F7FFEM0F8F80000003C7C0070001E03C1FM0FC7K0001CFC00FE003807C078L07C7040000608FC01FFC06007C078L07E60C0000701F80787E0C0078078L07E01C0000781F80F01F180078078L03F03C00007C1F00E00F980078078L03F07C00007E1F004007F000F00FM01F0F800007E1E200003F060F01EL010F1F800003F1C6K0F8F0F03CL01871F800003F00EK079F0FFF8L01C13F000001F80EK03FE1EFEM01E03F000001F81EL0FC1E3CM01F03E000000F83EN01C3CM01F07E000000783EN03C1EM01F87C000000383EN03C1EM01F83K01C087EN0381EN0F82070000F007EN0780FN0FC03E0000FC07CN0780FN0FC0FE00007F07CN0700F8M07C1FC00007F8784M0F0078L047C3F800003FC78CM0E0078L063C7F800001FE71CM0E003CL071CFF000000FE43CM0C003EL0708FE0000007E03CP01EL0F81F80000001F03CP01FL0F81FK0K07CQ0F8K0F81L0070007C2P07800C10FC003C00003F007C3P03C00C18FC01F800003FC07C7P01E00C187C0FF000001FF0FC7Q0F81C3C7C1FF000000FF87C78P07E383C7C3FE0000007FC78F8P01FE03C7C7FC0000003FC78F8T03E3CFFK0000FE70F88R043E18FEK00003E20F8CR047E08F8K0M0F8ER0E7EO0M0F8FQ01E7EO0000FE00F8FQ03E3E01FEK0000FFC0F8F8P03E3E0FFCK00007FF0F0F8P07E3C1FF8K00003FF870FCP07E1C3FFL00000FFC60FCP07C087FEL000003FC007C6M01CFC00FF8L0K0FC007C7CL0F8FC00FEM0O07E3FK03F8F8Q0L03C03C3FC00007F0F80F8N0K0FFF83C1FE0001FE0F07FFCM0K07FFE1C0FF0003FE060FFFCM0K03FFF0C07F8003FC041FFF8M0L0FFF0003F8007F8001FFEN0L01FC0000FC007E00007FO0P0E003C007801ER0O0FFCN07FEQ0N03FFE00038000FFF8P0N0FFFC00078000FFFEP0M01FFF80F0781E03FFFP0N07FE0FFC38FFC0FF8P0Q03FFE00FFFT0Q0FFFC007FFCS0P01FFF0003FFFS0Q07FC0000FFCS0,
^FS''';

    return '''^XA
    ^LL$alturaTotal
^LH0,0

$logoZPL

^FX ===== HEADER EMPRESA CENTRADO =====
^CF0,24,24
^FO0,190^FB360,2,0,C,0^FH^FD$empresaNombre^FS

^CF0,22,24
^FO0,225^FB360,1,0,C,0^FH^FDCasa Matriz^FS
^FO0,250^FB360,2,0,C,0^FH^FD$empresaDireccion^FS

^CF0,22,24
^FO0,290^FB360,1,0,C,0^FH^FDTel: $empresaTelefono^FS
^FO0,315^FB360,1,0,C,0^FH^FD$empresaCorreo^FS
^FO0,340^FB360,1,0,C,0^FH^FD $empresaRTN^FS

^FO0,365^GB360,2,2^FS                                 ← Cambié de 320 a 355


^FX ===== INFORMACION DE FACTURA IZQUIERDA =====
^CF0,22,24
^FO0,390^FB360,2,0,L,0^FDCAI: $cai^FS
^FO0,440^FB360,2,0,L,0^FDNo. Factura: $factNumero^FS
^FO0,490^FB360,1,0,L,0^FDFecha Emision: $factFecha^FS
^FO0,515^FB360,1,0,L,0^FDTipo Venta: $factTipo^FS
^FO0,540^FB360,1,0,L,0^FDCliente: $clienteNombre^FS
^FO0,565^FB360,1,0,L,0^FDCodigo Cliente: $clienteCodigo^FS
^FO0,590^FB360,2,0,L,0^FDDireccion cliente: $clienteDireccion^FS
^FO0,640^FB360,1,0,L,0^FDRTN cliente: $clienteRTN^FS
^FO0,665^FB360,1,0,L,0^FDVendedor: $vendedorNombre^FS
^FO0,690^FB360,1,0,L,0^FDNo Orden de compra exenta:^FS
^FO0,715^FB360,2,0,L,0^FDNo Constancia de reg de exonerados:^FS
^FO0,765^FB360,1,0,L,0^FDNo Registro de la SAG:^FS


^FX ===== TABLA PRODUCTOS (4 COLUMNAS) =====
^FO0,810^GB360,2,2^FS
^FO0,825^CF0,22,24^FDProd^FS
^FO165,825^CF0,22,24^FDCant^FS
^FO210,825^CF0,22,24^FDPrecio^FS
^FO295,825^CF0,22,24^FDMonto^FS
^FO0,845^GB360,1,1^FS

^FX ===== PRODUCTOS =====
$productosZPL

^FX ===== TOTALES =====
^FO0,$totalesY^GB360,2,2^FS
$totalesZPL

$footerZPL
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
    if (isoDate == null)
      return DateTime.now().toString().split(' ')[1].split('.')[0];
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
      diagnosis['canWriteWithoutResponse'] =
          _writeCharacteristic!.properties.writeWithoutResponse;
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
  Future<BluetoothDevice?> showPrinterSelectionDialog(
    BuildContext context,
  ) async {
    try {
      // Mostrar diálogo de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFF262B40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD5B58A)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Buscando impresoras...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Asegúrate de que la impresora esté encendida y en modo visible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Escanear dispositivos
      final devices = await startScan();
      if (context.mounted) Navigator.of(context).pop();

      if (devices.isEmpty) {
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: const Color(0xFF262B40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.print,
                      size: 48,
                      color: const Color(0xFFD5B58A),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se encontraron impresoras',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Verifica que la impresora esté encendida y en modo visible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD5B58A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'ENTENDIDO',
                          style: TextStyle(
                            color: Color(0xFF262B40),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return null;
      }

      return await showDialog<BluetoothDevice?>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: const Color(0xFF262B40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E344B),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.print_rounded,
                      color: const Color(0xFFD5B58A),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Seleccionar impresora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Lista de dispositivos
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(device),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD5B58A).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.print_rounded,
                                  color: const Color(0xFFD5B58A),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      device.id.id,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Botón de cancelar
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                    child: Text(
                      'CANCELAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }

        // Mostrar error con diseño mejorado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error al buscar impresoras: ${e.toString()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return null;
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    disconnect().catchError((e) => debugPrint('Error in dispose: $e'));
  }
}
