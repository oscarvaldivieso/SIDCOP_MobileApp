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

  // Check and request Bluetooth permissions
  Future<bool> _checkPermissions() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        debugPrint("Bluetooth not supported by this device");
        return false;
      }

      // Check if Bluetooth is on
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        debugPrint('Bluetooth is not on. Current state: $adapterState');
        // Note: FlutterBluePlus doesn't have turnOn() method
        // User needs to turn on Bluetooth manually
        return false;
      }

      // Request permissions
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
      // Get system devices (bonded devices)
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.bondedDevices;
      _devices = systemDevices.where((device) => 
        device.platformName.isNotEmpty &&
        (device.platformName.contains('ZQ') || 
         device.platformName.contains('Zebra') || 
         device.platformName.contains('BT'))
      ).toList();

      // Start scanning for more devices
      await _scanSubscription?.cancel();
      
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          if (device.platformName.isNotEmpty &&
              !_devices.any((d) => d.remoteId == device.remoteId) &&
              (device.platformName.contains('ZQ') || 
               device.platformName.contains('Zebra') || 
               device.platformName.contains('BT'))) {
            _devices.add(device);
          }
        }
      });

      // Wait for scan to complete
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

  // Connect to a Bluetooth device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      // Disconnect if already connected
      if (_isConnected) {
        await disconnect();
      }

      _connectedDevice = device;
      debugPrint('Connecting to ${device.platformName} (${device.remoteId})');

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      
      // Wait a bit for connection to establish
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if actually connected
      var connectionState = await device.connectionState.first;
      if (connectionState != BluetoothConnectionState.connected) {
        throw Exception('Failed to establish connection');
      }
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      // Look for a suitable characteristic for writing
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            _writeCharacteristic = characteristic;
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }

      _isConnected = true;
      debugPrint('Successfully connected to ${device.platformName}');
      return true;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _isConnected = false;
      _connectedDevice = null;
      _writeCharacteristic = null;
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

  // Print ZPL content directly (for Zebra ZQ310)
  Future<bool> printZPL(String zplContent) async {
    if (!_isConnected || _connectedDevice == null) {
      throw Exception('No hay una impresora conectada');
    }

    try {
      // For SPP (Serial Port Profile) printers like ZQ310,
      // we'll send data in chunks to avoid buffer overflow
      List<int> bytes = utf8.encode(zplContent);
      
      if (_writeCharacteristic != null) {
        // Use characteristic if available
        const int chunkSize = 20; // BLE characteristic limit
        for (int i = 0; i < bytes.length; i += chunkSize) {
          int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
          List<int> chunk = bytes.sublist(i, end);
          await _writeCharacteristic!.write(chunk);
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } else {
        // Fallback: try to find serial port service
        List<BluetoothService> services = await _connectedDevice!.discoverServices();
        
        // Look for Serial Port Profile UUID or similar
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic char in service.characteristics) {
            if (char.properties.writeWithoutResponse || char.properties.write) {
              const int chunkSize = 20;
              for (int i = 0; i < bytes.length; i += chunkSize) {
                int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
                List<int> chunk = bytes.sublist(i, end);
                await char.write(chunk, withoutResponse: char.properties.writeWithoutResponse);
                await Future.delayed(const Duration(milliseconds: 50));
              }
              debugPrint('ZPL sent to printer successfully');
              return true;
            }
          }
        }
      }
      
      debugPrint('ZPL sent to printer successfully');
      return true;
    } catch (e) {
      debugPrint('Error printing ZPL: $e');
      return false;
    }
  }

  // Alternative method for classic Bluetooth SPP
  Future<bool> printZPLClassic(String zplContent) async {
    if (!_isConnected || _connectedDevice == null) {
      throw Exception('No hay una impresora conectada');
    }

    try {
      // This is a simplified approach - for SPP printers,
      // you might need a different implementation
      List<int> bytes = utf8.encode(zplContent);
      
      // Try to send via any writable characteristic
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            // Send in chunks
            const int chunkSize = 512; // Larger chunks for SPP
            for (int i = 0; i < bytes.length; i += chunkSize) {
              int end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
              List<int> chunk = bytes.sublist(i, end);
              
              if (char.properties.writeWithoutResponse) {
                await char.write(chunk, withoutResponse: true);
              } else {
                await char.write(chunk);
              }
              await Future.delayed(const Duration(milliseconds: 100));
            }
            return true;
          }
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('Error in printZPLClassic: $e');
      return false;
    }
  }

  // Print test page for ZQ310
  Future<bool> printTest() async {
    if (!_isConnected || _connectedDevice == null) {
      throw Exception('No hay una impresora conectada');
    }

    try {
      // Simple ZPL test for ZQ310
      String testZPL = '''
^XA
^PW832
^LH0,0
^FO50,50^A0N,40,40^FDPRUEBA EXITOSA^FS
^FO50,100^A0N,25,25^FDZebra ZQ310^FS
^FO50,140^A0N,20,20^FDFecha: ${DateTime.now().toString().split(' ')[0]}^FS
^FO50,170^A0N,20,20^FDBluetooth LE OK^FS
^LL280
^XZ
''';
      
      // Try both methods
      bool success = await printZPL(testZPL);
      if (!success) {
        success = await printZPLClassic(testZPL);
      }
      return success;
    } catch (e) {
      debugPrint('Error printing test: $e');
      return false;
    }
  }

  // Print invoice
  Future<bool> printInvoice(Map<String, dynamic> invoiceData) async {
    try {
      if (!_isConnected) {
        throw Exception('Impresora no conectada');
      }

      // Simple invoice ZPL
      final zplContent = _generateSimpleInvoiceZPL(invoiceData);
      
      // Try both printing methods
      bool success = await printZPL(zplContent);
      if (!success) {
        success = await printZPLClassic(zplContent);
      }
      return success;
    } catch (e) {
      debugPrint('Error printing invoice: $e');
      rethrow;
    }
  }

  // Simple invoice ZPL generator
  String _generateSimpleInvoiceZPL(Map<String, dynamic> invoiceData) {
    final factNumero = invoiceData['fact_Numero'] ?? 'F001-0000001';
    final cliente = invoiceData['cliente'] ?? 'Cliente';
    final total = invoiceData['fact_Total']?.toString() ?? '0.00';
    final fecha = DateTime.now().toString().split(' ')[0];

    return '''
^XA
^PW832
^LH0,0
^FO50,30^A0N,30,30^FDSIDCOP^FS
^FO50,70^A0N,25,25^FDFactura: $factNumero^FS
^FO50,100^A0N,20,20^FDFecha: $fecha^FS
^FO50,130^A0N,20,20^FDCliente: $cliente^FS
^FO50,160^GB730,2,2^FS
^FO50,180^A0N,25,25^FDTOTAL: L $total^FS
^FO50,220^A0N,18,18^FDGracias por su compra^FS
^LL280
^XZ
''';
  }

  // Method to show printer selection dialog
  Future<BluetoothDevice?> showPrinterSelectionDialog(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Buscando impresoras...'),
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
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontraron impresoras Zebra cercanas.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return null;
      }

      return await showDialog<BluetoothDevice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Seleccionar Impresora'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.print,
                      color: Colors.blue,
                    ),
                    title: Text(
                      device.platformName.isNotEmpty ? device.platformName : 'Dispositivo desconocido',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${device.remoteId}'),
                        FutureBuilder<bool>(
                          future: device.connectionState.first.then((state) => state == BluetoothConnectionState.connected),
                          builder: (context, snapshot) {
                            bool isConnected = snapshot.data ?? false;
                            return Text('Estado: ${isConnected ? 'Conectado' : 'Disponible'}');
                          },
                        ),
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
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al buscar impresoras: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  // Cleanup resources
  void dispose() {
    _scanSubscription?.cancel();
    // Don't await disconnect in dispose - just trigger it
    disconnect().catchError((e) => debugPrint('Error in dispose disconnect: $e'));
  }
}