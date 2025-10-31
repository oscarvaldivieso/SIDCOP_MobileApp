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
    _autoConnectToPrinter(); // Intentar conectar automáticamente
  }

  // Conectar automáticamente a la impresora guardada
  Future<void> _autoConnectToPrinter() async {
    // Esperar un momento para que la UI se cargue
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Si ya está conectado, no hacer nada
    if (_printerService.isConnected) {
      setState(() {
        _isConnected = true;
        _connectedDevice = _printerService.connectedDevice;
      });
      return;
    }

    // Intentar reconectar a la impresora guardada
    try {
      final savedPrinter = await _printerService.getSavedPrinter();
      
      if (savedPrinter != null && mounted) {
        // Mostrar mensaje de reconexión
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Conectando a ${savedPrinter['name']}...'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );

        final reconnected = await _printerService.tryReconnectToSavedPrinter();
        
        if (mounted) {
          setState(() {
            _isConnected = reconnected;
            _connectedDevice = reconnected ? _printerService.connectedDevice : null;
          });

          if (reconnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Conectado a ${savedPrinter['name']}'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Silenciosamente fallar si no se puede reconectar
      debugPrint('No se pudo reconectar automáticamente: $e');
    }
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
      
      // Mostrar resultado del escaneo
      if (mounted) {
        if (_devices.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Dispositivos encontrados',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Satoshi',
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Se encontraron ${_devices.length} dispositivo(s)',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No se encontraron dispositivos',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Satoshi',
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Verifica que tu impresora esté encendida',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Error al escanear',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Satoshi',
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.toString(),
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
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
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        success ? '¡Conexión exitosa!' : 'Error de conexión',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Satoshi',
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        success 
                            ? 'Conectado a ${device.platformName}'
                            : 'No se pudo conectar a la impresora',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: success ? Colors.green.shade600 : Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Error inesperado',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Satoshi',
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Error de conexión: ${e.toString()}',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Desconectar la impresora
  Future<void> _disconnectPrinter() async {
    try {
      await _printerService.disconnect();
      await _printerService.clearSavedPrinter(); // Limpiar impresora guardada
      setState(() {
        _isConnected = false;
        _connectedDevice = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impresora desconectada y configuración eliminada'),
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
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, color: Color(0xFF1a1d3a)),
                      onPressed: () => _probarImpresora(),
                      tooltip: 'Probar impresión',
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_off, color: Colors.red),
                      onPressed: _disconnectPrinter,
                      tooltip: 'Desconectar',
                    ),
                  ],
                )
              : const Icon(Icons.chevron_right, color: Color(0xFF666666)),
          onTap: _isConnected ? null : () => _showPrinterBottomSheet(),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Future<void> _probarImpresora() async {
  if (!_isConnected || _connectedDevice == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay ninguna impresora conectada',
            style: TextStyle(fontFamily: 'Satoshi'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }

  // Mostrar diálogo de carga
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Enviando prueba de impresión...',
              style: TextStyle(fontFamily: 'Satoshi'),
            ),
          ],
        ),
      );
    },
  );

  try {
    // PRIMERO: Verificar que la impresora sigue conectada
    final connectionState = await _connectedDevice!.connectionState.first
        .timeout(const Duration(seconds: 3));
    
    if (connectionState != BluetoothConnectionState.connected) {
      throw Exception('La impresora se desconectó');
    }

    // SEGUNDO: Intentar imprimir la prueba
    final bool resultado = await _printerService.printTest();

    // Cerrar el diálogo de carga
    if (mounted) {
      Navigator.of(context).pop();
    }

    // TERCERO: Mostrar resultado
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                resultado ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  resultado
                      ? 'Prueba de impresión enviada correctamente'
                      : 'Error al enviar prueba de impresión',
                  style: const TextStyle(fontFamily: 'Satoshi'),
                ),
              ),
            ],
          ),
          backgroundColor: resultado ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } on TimeoutException {
    // Cerrar el diálogo de carga
    if (mounted) {
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tiempo de espera agotado. Verifica la conexión.',
            style: TextStyle(fontFamily: 'Satoshi'),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    // Cerrar el diálogo de carga en caso de error
    if (mounted) {
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: const TextStyle(fontFamily: 'Satoshi'),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}


  // Mostrar bottom sheet con opciones de impresora - DISEÑO MODERNO
  void _showPrinterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle bar moderno
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header con gradiente
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.white,
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF141A2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.print_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Configurar Impresora',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Satoshi',
                                  color: Color(0xFF141A2F)
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Conecta tu impresora Bluetooth',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Satoshi',
                                  color: Color(0xFF141A2F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenido
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Botón de escaneo moderno
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: _isScanning 
                                  ? LinearGradient(
                                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                                    )
                                  : const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF141A2F), Color(0xFF2A3550)],
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _isScanning ? [] : [
                                BoxShadow(
                                  color: const Color(0xFF141A2F).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _isScanning ? null : () async {
                                  setModalState(() => _isScanning = true);
                                  await _scanForPrinters();
                                  setModalState(() => _isScanning = false);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isScanning)
                                        const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.radar_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _isScanning ? 'Buscando dispositivos...' : 'Buscar Impresoras',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Satoshi',
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                      
                      // Lista de dispositivos encontrados
                      Expanded(
                        child: _devices.isEmpty && !_isScanning
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.bluetooth_searching_rounded,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No hay dispositivos',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Satoshi',
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Presiona "Buscar Impresoras"\npara escanear dispositivos cercanos',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'Satoshi',
                                        color: Colors.grey.shade500,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _isScanning
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 60,
                                          height: 60,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 4,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              const Color(0xFF141A2F),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Buscando dispositivos...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Satoshi',
                                            color: Color(0xFF141A2F),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Asegúrate de que tu impresora\nesté encendida y visible',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Satoshi',
                                            color: Colors.grey.shade600,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _devices.length,
                                    itemBuilder: (context, index) {
                                      final device = _devices[index];
                                      final isConnected = _isConnected && 
                                          _connectedDevice?.remoteId == device.remoteId;
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: isConnected 
                                              ? Colors.blue.withOpacity(0.05)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: isConnected 
                                                ? const Color(0xFF141A2F)
                                                : Colors.grey.shade200,
                                            width: isConnected ? 2 : 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isConnected 
                                                  ? const Color(0xFF141A2F).withOpacity(0.1)
                                                  : Colors.black.withOpacity(0.03),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () async {
                                              // Mostrar loader durante conexión
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => Dialog(
                                                  backgroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(32),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const SizedBox(
                                                          width: 50,
                                                          height: 50,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 4,
                                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                             Color(0xFF141A2F),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(height: 24),
                                                        Text(
                                                          'Conectando...',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w600,
                                                            fontFamily: 'Satoshi',
                                                            color: Colors.grey.shade800,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          device.platformName.isNotEmpty 
                                                              ? device.platformName 
                                                              : 'Dispositivo',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontFamily: 'Satoshi',
                                                            color: Colors.grey.shade600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                              
                                              await _connectToPrinter(device);
                                              
                                              if (mounted) {
                                                Navigator.of(context).pop(); // Cerrar loader
                                              }
                                              
                                              setModalState(() {});
                                              
                                              if (_isConnected && mounted) {
                                                Navigator.pop(context); // Cerrar bottom sheet
                                              }
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      gradient: isConnected
                                                          ? const LinearGradient(
                                                              colors: [Color(0xFF141A2F), Color(0xFF141A2F)],
                                                            )
                                                          : LinearGradient(
                                                              colors: [
                                                                Colors.grey.shade100,
                                                                Colors.grey.shade200,
                                                              ],
                                                            ),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Icon(
                                                      isConnected 
                                                          ? Icons.check_circle_rounded
                                                          : Icons.print_rounded,
                                                      color: isConnected 
                                                          ? Colors.white
                                                          : const Color(0xFF141A2F),
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          device.platformName.isNotEmpty 
                                                              ? device.platformName 
                                                              : 'Dispositivo desconocido',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w600,
                                                            fontFamily: 'Satoshi',
                                                            color: isConnected 
                                                                ? const Color(0xFF141A2F)
                                                                : Colors.grey.shade800,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons.bluetooth_rounded,
                                                              size: 14,
                                                              color: Colors.grey.shade500,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                device.remoteId.toString(),
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontFamily: 'Satoshi',
                                                                  color: Colors.grey.shade500,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        if (isConnected) ...[
                                                          const SizedBox(height: 8),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.green.shade50,
                                                              borderRadius: BorderRadius.circular(6),
                                                              border: Border.all(
                                                                color: Colors.green.shade200,
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  Icons.check_circle,
                                                                  size: 12,
                                                                  color: Colors.green.shade700,
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  'Conectado',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w600,
                                                                    fontFamily: 'Satoshi',
                                                                    color: Colors.green.shade700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: Colors.grey.shade400,
                                                    size: 24,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  },
);
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar separado del body
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0), // Sin altura visible
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección superior con fondo SVG
            Container(
              width: double.infinity,
              height: 300,
              color: const Color(0xFF1a1d3a),
              child: Stack(
                children: [
                  // Imagen SVG de fondo con flip horizontal y opacidad
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
                    top: 120,
                    left: 0,
                    right: 0,
                    child: Center(
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
                  ),
                  // AppBar personalizado en la parte superior
                  SafeArea(
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF1a1d3a).withOpacity(0.95),
                            const Color(0xFF1a1d3a).withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          // Botón de regreso
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Configuración',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Satoshi',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
                      const SizedBox(height: 24),
                      
                      // Sección de configuración de impresora
                      _buildPrinterSection(),
                      
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