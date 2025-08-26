import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';

import '../../../services/ConfiguracionSerivice.Dart';
import '../../../services/printer_service.dart';
import '../../widgets/OfflineConfigWidget.dart';

class ConfiguracionScreen extends StatefulWidget {
  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  bool isOnline = true;
  final PrinterService _printerService = PrinterService();
  bool _isScanning = false;
  bool _isConnected = false;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _connectedDevice;

  /// Método para limpiar la caché con confirmación del usuario
  Future<void> _limpiarCache() async {
    // Mostrar diálogo de confirmación
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Limpiar Caché', style: TextStyle(fontFamily: 'Satoshi')),
          content: Text('¿Está seguro de que desea limpiar toda la memoria caché? Esta acción eliminará todos los datos almacenados temporalmente.', style: TextStyle(fontFamily: 'Satoshi')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar', style: TextStyle(fontFamily: 'Satoshi')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Limpiar', style: TextStyle(color: Colors.red, fontFamily: 'Satoshi')),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Limpiando caché...', style: TextStyle(fontFamily: 'Satoshi')),
              ],
            ),
          );
        },
      );

      try {
        // Llamar al servicio para limpiar caché
        bool resultado = await ConfiguracionService.limpiarCache();
        
        // Cerrar el diálogo de carga
        Navigator.of(context).pop();
        
        // Mostrar resultado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado 
                ? 'Caché limpiado exitosamente' 
                : 'Error al limpiar caché',
              style: TextStyle(fontFamily: 'Satoshi'),
            ),
            backgroundColor: resultado ? Colors.green : Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        // Cerrar el diálogo de carga en caso de error
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado al limpiar caché', style: TextStyle(fontFamily: 'Satoshi')),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Inicialización y limpieza
  @override
  void initState() {
    super.initState();
    _checkPrinterStatus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Verificar estado de la impresora
  Future<void> _checkPrinterStatus() async {
    setState(() {
      _isConnected = _printerService.isConnected;
      _connectedDevice = _printerService.connectedDevice;
    });
  }

  // Escanear dispositivos Bluetooth
  Future<void> _scanForPrinters() async {
    try {
      setState(() => _isScanning = true);
      _devices = await _printerService.startScan();
      setState(() => _isScanning = false);
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al escanear: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Conectar a una impresora
  Future<void> _connectToPrinter(BluetoothDevice device) async {
    try {
      final success = await _printerService.connect(device);
      setState(() {
        _isConnected = success;
        _connectedDevice = success ? device : null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? 'Conectado a ${device.platformName}'
                : 'No se pudo conectar a la impresora',
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Desconectar la impresora
  Future<void> _disconnectPrinter() async {
    try {
      await _printerService.disconnect();
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impresora desconectada'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al desconectar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Construir la sección de configuración de impresora
  Widget _buildPrinterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Impresora',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
            fontFamily: 'Satoshi',
          ),
        ),
        const SizedBox(height: 12),
        
        // Estado de conexión
        ListTile(
          leading: Icon(
            _isConnected ? Icons.check_circle : Icons.print_disabled_outlined,
            color: _isConnected ? Colors.green : Color(0xFF666666),
          ),
          title: Text(
            _isConnected 
                ? 'Conectado'
                : 'Sin conexión',
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 16,
              color: Color(0xFF333333),
            ),
          ),
          subtitle: Text(
            _isConnected 
                ? '${_connectedDevice?.platformName ?? 'Dispositivo desconocido'}'
                : 'Conectar impresora Bluetooth',
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          trailing: _isConnected 
              ? IconButton(
                  icon: const Icon(Icons.link_off, color: Colors.red),
                  onPressed: _disconnectPrinter,
                )
              : const Icon(Icons.chevron_right, color: Color(0xFF666666)),
          onTap: _isConnected ? null : () => _showPrinterBottomSheet(),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // Mostrar bottom sheet con opciones de impresora
  void _showPrinterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header del bottom sheet
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Configurar Impresora',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Satoshi',
                              color: Color(0xFF141A2F),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Botón de escaneo
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _isScanning 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.search, size: 20),
                          label: Text(_isScanning ? 'Buscando...' : 'Buscar impresoras'),
                          onPressed: _isScanning ? null : () async {
                            await _scanForPrinters();
                            setModalState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141A2F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Lista de dispositivos encontrados
                      Expanded(
                        child: _devices.isEmpty && !_isScanning
                            ? const Center(
                                child: Text(
                                  'No se encontraron dispositivos.\nPresiona "Buscar impresoras" para escanear.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Satoshi',
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _devices.length,
                                itemBuilder: (context, index) {
                                  final device = _devices[index];
                                  final isConnected = _isConnected && 
                                      _connectedDevice?.remoteId == device.remoteId;
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 2,
                                    child: ListTile(
                                      leading: const Icon(Icons.print, color: Color(0xFF4B5563)),
                                      title: Text(
                                        device.platformName.isNotEmpty 
                                            ? device.platformName 
                                            : 'Dispositivo desconocido',
                                        style: const TextStyle(fontFamily: 'Satoshi'),
                                      ),
                                      subtitle: Text(
                                        device.remoteId.toString(),
                                        style: const TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: isConnected
                                          ? const Icon(Icons.check_circle, color: Colors.green)
                                          : const Icon(Icons.bluetooth, color: Colors.blue),
                                      onTap: () async {
                                        await _connectToPrinter(device);
                                        setModalState(() {});
                                        if (_isConnected) {
                                          Navigator.pop(context);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco para toda la pantalla
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección superior con fondo SVG como UserInfoScreen
            Container(
              width: double.infinity,
              height: 300,
              color: const Color(0xFF1a1d3a),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Imagen SVG de fondo con flip horizontal y opacidad (igual que UserInfoScreen)
                  SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: ClipRRect(
                      child: Opacity(
                        opacity: 0.4,
                        child: Transform.flip(
                          child: SvgPicture.asset(
                            'assets/FondoNuevo2.svg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Ícono de configuración
                  Positioned(
                    top: 100,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.settings,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // AppBar personalizado integrado
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      color: const Color(0xFF1a1d3a),
                      child: SafeArea(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text(
                              'Configuración',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Contenido principal con fondo blanco
            Transform.translate(
              offset: const Offset(0, -50),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección Cuenta alineada a la izquierda
                      const Text(
                        'Cuenta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Widget de configuración offline
                      const OfflineConfigWidget(),
                      
                      const SizedBox(height: 24),
                      
                      // Sección de configuración de impresora AQUÍ
                      _buildPrinterSection(),
                      
                      const SizedBox(height: 24),
                      
                      // Sección Acerca de
                      const Text(
                        'Acerca de',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: Color(0xFF666666)),
                        title: const Text(
                          'Ayuda y soporte',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF333333),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: Color(0xFF666666)),
                        title: const Text(
                          'Términos y condiciones',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF333333),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Sección Almacenamiento y sincronización
                      const Text(
                        'Almacenamiento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Color(0xFF666666)),
                        title: const Text(
                          'Limpiar caché',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF333333),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                        onTap: () => _limpiarCache(),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Espacio adicional para asegurar fondo blanco completo
            Container(
              height: 100,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}