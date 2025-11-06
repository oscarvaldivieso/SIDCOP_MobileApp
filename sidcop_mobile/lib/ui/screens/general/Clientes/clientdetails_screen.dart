// Importaciones necesarias para la pantalla de detalles del cliente
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/services/ClientImageCacheService.dart';
import 'package:sidcop_mobile/ui/screens/venta/venta_screen.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/client_location_screen.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/ui/screens/pedidos/pedidos_create_screen.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/Offline_Services/Clientes_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/CuentasPorCobrar_OfflineService.dart';
import 'package:sidcop_mobile/services/cuentasPorCobrarService.dart';
import 'package:sidcop_mobile/ui/screens/venta/cuentasPorCobrarDetails_screen.dart';
import 'package:sidcop_mobile/models/ventas/cuentasporcobrarViewModel.dart';

/// Pantalla que muestra los detalles completos de un cliente específico
/// Incluye información personal, direcciones, imagen y acciones disponibles
class ClientdetailsScreen extends StatefulWidget {
  final int clienteId;

  const ClientdetailsScreen({super.key, required this.clienteId});

  @override
  State<ClientdetailsScreen> createState() => _ClientdetailsScreenState();
}

class _ClientdetailsScreenState extends State<ClientdetailsScreen> {
  // Servicio para operaciones con clientes
  final ClientesService _clientesService = ClientesService();
  
  // Servicio para operaciones con cuentas por cobrar
  final CuentasXCobrarService _cuentasService = CuentasXCobrarService();
  
  // Datos del cliente
  Map<String, dynamic>? _cliente;
  
  // Lista de direcciones del cliente
  List<dynamic> _direcciones = [];
  
  // Estado de carga
  bool _isLoading = true;
  
  // Mensaje de error si ocurre algún problema
  String _errorMessage = '';
  
  // Tipo de vendedor (P = Pedidos, V = Ventas)
  String? _vendTipo;

  int? _roleId;
  
  // Estado de cuentas por cobrar
  bool _tieneCuentasPorCobrar = false;
  bool _isLoadingCuentas = false;
  List<dynamic> permisos = [];
  final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();
  CuentasXCobrar? _cuentaParaCobrar;

  @override
  void initState() {
    super.initState();
    // Cargar datos del cliente y tipo de vendedor al iniciar
    _loadCliente();
    _loadTipoVendedor();
    _loadPermisos();
    // Verificar cuentas por cobrar después de un pequeño delay para asegurar que el widget esté montado
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _verificarCuentasPorCobrar();
      }
    });
  }

  bool tienePermiso(int pantId) {
    return permisos.any((p) => p['Pant_Id'] == pantId);
  }

  Future<void> _loadPermisos() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    if (userData != null &&
        (userData['PermisosJson'] != null ||
            userData['permisosJson'] != null)) {
      try {
        final permisosJson =
            userData['PermisosJson'] ?? userData['permisosJson'];
        permisos = jsonDecode(permisosJson);
      } catch (_) {
        permisos = [];
      }
    }
    setState(() {});
  }

  // ID de persona del usuario actual
  String? _usuaIdPersona;
  
  Future<void> _loadTipoVendedor() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    setState(() {
      // Extraer tipo de vendedor de los datos del usuario
      _vendTipo =
          userData?['datosVendedor']?['vend_Tipo'] ?? userData?['vend_Tipo'];
      _roleId = userData?['role_Id'] ?? 0;
      // Extraer ID de persona del usuario
      _usuaIdPersona = userData?['usua_IdPersona']?.toString();
    });
  }

  /// Carga los datos completos del cliente desde el servidor o almacenamiento local
  /// Maneja tanto el flujo online como offline

  Future<void> _loadCliente() async {
    try {
      // Verificar si hay conexión a internet
      final hasConnection = await SyncService.hasInternetConnection();
      Map<String, dynamic>? cliente;

      if (hasConnection) {
        // FLUJO ONLINE: Obtener datos del servidor
        cliente = await _clientesService.getClienteById(widget.clienteId);
        // Guardar en almacenamiento local para uso offline
        await ClientesOfflineService.guardarDetalleCliente(cliente);
      } else {
        // FLUJO OFFLINE: Cargar desde almacenamiento local
        cliente = await ClientesOfflineService.cargarDetalleCliente(widget.clienteId);
      }

      // Actualizar el estado con los datos del cliente
      setState(() {
        _cliente = cliente;
        _isLoading = false;
      });

      // Cargar las direcciones del cliente
      await _loadDireccionesCliente();
    } catch (e) {
      // Manejar errores durante la carga
      setState(() {
        _errorMessage = 'Error al cargar los datos del cliente';
        _isLoading = false;
      });
    }
  }

  /// Carga todas las direcciones del cliente
  /// Filtra las direcciones para mostrar solo las del cliente actual

  Future<void> _loadDireccionesCliente() async {
    if (!mounted) return;

    try {
      // Verificar conexión a internet
      final hasConnection = await SyncService.hasInternetConnection();
      List<dynamic> direcciones;

      if (hasConnection) {
        // FLUJO ONLINE: Obtener direcciones del servidor
        direcciones = await _clientesService.getDireccionesPorCliente();
        // Guardar en almacenamiento local
        await ClientesOfflineService.guardarJson('direcciones.json', direcciones);
      } else {
        // FLUJO OFFLINE: Cargar desde almacenamiento local
        final raw = await ClientesOfflineService.leerJson('direcciones.json');
        direcciones = raw != null ? List<dynamic>.from(raw) : [];
      }

      // Filtrar solo las direcciones del cliente actual
      final direccionesFiltradas = direcciones.where((dir) {
        final clienteId = dir['clie_Id'];
        return clienteId == widget.clienteId;
      }).toList();

      // Actualizar el estado con las direcciones filtradas
      if (mounted) {
        setState(() {
          _direcciones = direccionesFiltradas;
        });
      }
    } catch (e) {
      // Manejar errores durante la carga de direcciones
      if (mounted) {
        setState(() {
          _errorMessage = 'Error cargando direcciones: ${e.toString()}';
        });
      }
    }
  }

  /// Verifica si el cliente tiene cuentas por cobrar pendientes
  Future<void> _verificarCuentasPorCobrar() async {
    if (!mounted) return;
    
    print('🔍 Verificando cuentas por cobrar para cliente ID: ${widget.clienteId}');
    
    try {
      setState(() {
        _isLoadingCuentas = true;
      });

      // Verificar si hay conexión a internet
      final hasConnection = await SyncService.hasInternetConnection();
      print('🌐 Conexión a internet: $hasConnection');
      
      if (hasConnection) {
        // FORZAR LIMPIEZA DE CACHE ANTES DE VERIFICAR
        print('🧹 Limpiando cache de cuentas por cobrar para datos frescos...');
        await _limpiarCacheCliente();
        
        print('📡 Llamando al servidor para verificar cuentas por cobrar...');
        // Verificar en el servidor con datos frescos
        final resultado = await _cuentasService.verificarCuentasPorCobrarCliente(widget.clienteId);
        
        print('📋 Resultado del servidor: $resultado');
        print('📊 Code Status: ${resultado['code_Status']}');
        print('💬 Message Status: ${resultado['message_Status']}');
        
        if (mounted) {
          setState(() {
            _tieneCuentasPorCobrar = resultado['code_Status'] == 1;
            _isLoadingCuentas = false;
          });
          
          print('✅ Estado actualizado - Tiene cuentas por cobrar: $_tieneCuentasPorCobrar');
        }
        
        // Si tiene cuentas por cobrar, obtener la primera cuenta para navegar
        if (_tieneCuentasPorCobrar) {
          print('🔄 Obteniendo primera cuenta por cobrar...');
          await _obtenerPrimeraCuentaPorCobrar();
        } else {
          print('✅ Cliente sin cuentas pendientes - ocultando botón COBRAR');
        }
      } else {
        print('❌ Sin conexión, ocultando botón por seguridad');
        // Sin conexión, no mostrar el botón por seguridad
        if (mounted) {
          setState(() {
            _tieneCuentasPorCobrar = false;
            _isLoadingCuentas = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error verificando cuentas por cobrar: $e');
      if (mounted) {
        setState(() {
          _tieneCuentasPorCobrar = false;
          _isLoadingCuentas = false;
        });
      }
    }
  }

  /// Limpia el cache de cuentas por cobrar para obtener datos frescos
  Future<void> _limpiarCacheCliente() async {
    try {
      print('🧹 Forzando recarga completa de datos de cuentas por cobrar...');
      
      // Forzar recarga completa de datos de cuentas por cobrar
      await CuentasPorCobrarOfflineService.forzarRecargaCompleta();
      
      print('✅ Cache limpiado - datos frescos disponibles');
    } catch (e) {
      print('⚠️ Error limpiando cache: $e');
      // No es crítico si falla la limpieza, continuar con la verificación
    }
  }

  /// Obtiene la primera cuenta por cobrar del cliente para navegar al detalle
  Future<void> _obtenerPrimeraCuentaPorCobrar() async {
    try {
      print('📅 Obteniendo timeline del cliente ${widget.clienteId}...');
      // Obtener el timeline del cliente para encontrar una cuenta
      final timeline = await _cuentasService.getTimelineCliente(widget.clienteId);
      
      print('📋 Timeline obtenido: ${timeline.length} elementos');
      
      if (timeline.isNotEmpty && mounted) {
        // Buscar la primera cuenta no saldada
        for (int i = 0; i < timeline.length; i++) {
          final item = timeline[i];
          try {
            print('🔍 Procesando item $i del timeline: $item');
            final cuenta = CuentasXCobrar.fromJson(item);
            print('💰 Cuenta ID: ${cuenta.cpCo_Id}, Saldada: ${cuenta.cpCo_Saldada}, Saldo: ${cuenta.cpCo_Saldo}');
            
            // Usar la primera cuenta que no esté saldada, independientemente del saldo
            if (cuenta.cpCo_Saldada != true && cuenta.cpCo_Id != null) {
              setState(() {
                _cuentaParaCobrar = cuenta;
              });
              print('✅ Primera cuenta por cobrar encontrada: ID ${cuenta.cpCo_Id} (Saldo en timeline: ${cuenta.cpCo_Saldo})');
              break;
            }
          } catch (e) {
            print('❌ Error parseando cuenta del timeline item $i: $e');
          }
        }
        
        if (_cuentaParaCobrar == null) {
          print('⚠️ No se encontró ninguna cuenta pendiente en el timeline');
          print('📊 Resumen del timeline:');
          for (int i = 0; i < timeline.length; i++) {
            try {
              final cuenta = CuentasXCobrar.fromJson(timeline[i]);
              print('   - Item $i: ID=${cuenta.cpCo_Id}, Saldada=${cuenta.cpCo_Saldada}, Saldo=${cuenta.cpCo_Saldo}');
            } catch (e) {
              print('   - Item $i: Error parseando - $e');
            }
          }
        }
      } else {
        print('⚠️ Timeline vacío o widget no montado');
      }
    } catch (e) {
      print('❌ Error obteniendo primera cuenta por cobrar: $e');
    }
  }

  /// Navega usando la primera cuenta encontrada en el timeline
  Future<void> _navegarConPrimeraCuenta() async {
    try {
      print('🔍 Buscando primera cuenta en timeline...');
      final timeline = await _cuentasService.getTimelineCliente(widget.clienteId);
      
      if (timeline.isNotEmpty) {
        for (final item in timeline) {
          try {
            final cuenta = CuentasXCobrar.fromJson(item);
            print('🔍 Evaluando cuenta: ID=${cuenta.cpCo_Id}, Saldada=${cuenta.cpCo_Saldada}, Saldo=${cuenta.cpCo_Saldo}');
            
            // Usar la primera cuenta que no esté saldada, independientemente del saldo
            if (cuenta.cpCo_Saldada != true && cuenta.cpCo_Id != null) {
              // Crear una copia con el ID correcto del cliente
              final cuentaCorregida = CuentasXCobrar(
                cpCo_Id: cuenta.cpCo_Id,
                clie_Id: widget.clienteId, // Usar el ID correcto del cliente
                fact_Id: cuenta.fact_Id,
                cpCo_FechaEmision: cuenta.cpCo_FechaEmision,
                cpCo_FechaVencimiento: cuenta.cpCo_FechaVencimiento,
                cpCo_Valor: cuenta.cpCo_Valor,
                cpCo_Saldo: cuenta.monto ?? cuenta.cpCo_Saldo, // Usar monto si está disponible
                cpCo_Observaciones: cuenta.cpCo_Observaciones,
                cpCo_Anulado: cuenta.cpCo_Anulado,
                cpCo_Saldada: cuenta.cpCo_Saldada,
                cliente: _cliente?['clie_Nombre'] ?? 'Cliente',
                clie_Nombres: _cliente?['clie_Nombres'] ?? '',
                clie_Apellidos: _cliente?['clie_Apellidos'] ?? '',
                monto: cuenta.monto,
                totalPendiente: cuenta.monto ?? cuenta.totalPendiente, // Usar monto como totalPendiente
              );
              
              print('💰 Fallback - Cuenta corregida - Monto: ${cuentaCorregida.monto}, TotalPendiente: ${cuentaCorregida.totalPendiente}');
              
              print('✅ Usando cuenta corregida: ID=${cuentaCorregida.cpCo_Id}, Cliente=${cuentaCorregida.clie_Id}, Monto=${cuentaCorregida.monto}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CuentasPorCobrarDetailsScreen(
                    cuentaId: widget.clienteId, // Usar el ID del cliente
                    cuentaResumen: cuentaCorregida,
                  ),
                ),
              );
              return;
            }
          } catch (e) {
            print('❌ Error parseando cuenta: $e');
          }
        }
      }
      
      print('⚠️ No se encontró ninguna cuenta válida para navegar');
    } catch (e) {
      print('❌ Error obteniendo timeline para navegación: $e');
    }
  }

  /// Construye un campo de información con etiqueta y valor
  /// Utilizado para mostrar los datos del cliente de forma consistente

  // Build a field with label above value
  Widget _buildInfoField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF141A2F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Satoshi',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  /// Construye la interfaz de usuario de la pantalla
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Asegurar que el drawer tenga una elevación mayor que los botones
      drawerScrimColor: Colors.black54,
      drawerEnableOpenDragGesture: true,
      body: Stack(
        children: [
          AppBackground(
            title: 'Detalles del Cliente',
            icon: Icons.person_outline,
            // Función de recarga al deslizar hacia abajo
            onRefresh: () async {
              _loadCliente();
            },
            // Mostrar diferentes estados: cargando, error, sin datos, o contenido
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(fontFamily: 'Satoshi'),
                    ),
                  )
                : _cliente == null
                ? const Center(
                    child: Text(
                      'No se encontró información del cliente',
                      style: const TextStyle(fontFamily: 'Satoshi'),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del cliente con botón de regreso
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          child: Row(
                            children: [
                              // Botón de regreso
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  size: 24,
                                  color: Color(0xFF141A2F),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Nombre completo del cliente
                              Expanded(
                                child: Text(
                                  '${_cliente!['clie_Nombres'] ?? ''} ${_cliente!['clie_Apellidos'] ?? ''}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Imagen del negocio del cliente
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Container(
                            width: double.infinity,
                            height: 200,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              // Mostrar imagen del negocio o avatar por defecto
                              child: _cliente!['clie_ImagenDelNegocio'] != null
                                  ? ClientImageCacheService().getCachedClientImage(
                                      imageUrl: _cliente!['clie_ImagenDelNegocio'],
                                      clientId: _cliente!['clie_Id'].toString(),
                                      width: MediaQuery.of(context).size.width - 48,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      errorWidget: _buildDefaultAvatar(),
                                    )
                                  : _buildDefaultAvatar(),
                            ),
                          ),
                        ),

                        // Información detallada del cliente
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre completo del cliente
                              _buildInfoField(
                                label: 'Cliente:',
                                value:
                                    '${_cliente!['clie_Nombres'] ?? ''} ${_cliente!['clie_Apellidos'] ?? ''}'
                                        .trim(),
                              ),
                              const SizedBox(height: 12),

                              // RTN (Registro Tributario Nacional)
                              if (_cliente!['clie_RTN'] != null &&
                                  _cliente!['clie_RTN'].toString().isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoField(
                                      label: 'RTN:',
                                      value: _cliente!['clie_RTN'].toString(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),

                              // Correo electrónico del cliente
                              if (_cliente!['clie_Correo'] != null &&
                                  _cliente!['clie_Correo']
                                      .toString()
                                      .isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoField(
                                      label: 'Correo:',
                                      value: _cliente!['clie_Correo']
                                          .toString(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),

                              // Número de teléfono del cliente
                              if (_cliente!['clie_Telefono'] != null &&
                                  _cliente!['clie_Telefono']
                                      .toString()
                                      .isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoField(
                                      label: 'Teléfono:',
                                      value: _cliente!['clie_Telefono']
                                          .toString(),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),

                              // Ruta asignada al cliente
                              if (_cliente!['ruta_Descripcion'] != null &&
                                  _cliente!['ruta_Descripcion']
                                      .toString()
                                      .isNotEmpty)
                                _buildInfoField(
                                  label: 'Ruta:',
                                  value: _cliente!['ruta_Descripcion']
                                      .toString(),
                                ),
                            ],
                          ),
                        ),

                        // Botón para ver las ubicaciones del cliente en el mapa
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Opacity(
                            // Deshabilitar visualmente si no hay direcciones
                            opacity: _direcciones.isNotEmpty ? 1.0 : 0.5,
                            child: AbsorbPointer(
                              // Deshabilitar interacción si no hay direcciones
                              absorbing: _direcciones.isEmpty,
                              child: CustomButton(
                                text: 'IR A LA UBICACIÓN',
                                onPressed: () {
                                  // Navegar a la pantalla de ubicaciones
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ClientLocationScreen(
                                            locations:
                                                List<Map<String, dynamic>>.from(
                                                  _direcciones,
                                                ),
                                            clientName:
                                                _cliente?['clie_Nombre'] ??
                                                'Cliente',
                                          ),
                                    ),
                                  );
                                },
                                height: 50,
                                fontSize: 14,
                                icon: const Icon(
                                  Icons.location_pin,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sección de botones de acción (Pedido/Venta y Cobrar)
                        if (_cliente != null &&
                            !_isLoading &&
                            _errorMessage.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 16.0,
                            ),
                            child: Row(
                              children: [
                                // Botón de Pedido o Venta según el tipo de vendedor
                                if ( tienePermiso(57) || tienePermiso(38))
                                  Expanded(
                                    child: CustomButton(
                                      text: _vendTipo == "P"
                                          ? "PEDIDO"
                                          : _vendTipo == "V"
                                          ? "VENTA"
                                          : tienePermiso(57)
                                          ? "VENTA"
                                          : tienePermiso(38)
                                          ? "PEDIDO"
                                          : "ACCIÓN",
                                      onPressed: () {
                                        if (tienePermiso(38)) {
                                          // Navegar a crear pedido
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PedidosCreateScreen(
                                                    clienteId: widget.clienteId,
                                                  ),
                                            ),
                                          );
                                        } else {
                                          // Navegar a crear venta
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => VentaScreen(
                                                clienteId: widget.clienteId,
                                                vendedorId: _usuaIdPersona != null ? int.tryParse(_usuaIdPersona!) : null,
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      height: 50,
                                      fontSize: 14,
                                      icon: Icon(
                                        _roleId == 83
                                            ? Icons.assignment
                                            : _roleId == 2
                                            ? Icons.shopping_cart
                                            : Icons.help_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),

                                // Espaciado condicional entre botones
                                if ((_roleId == 83 || _roleId == 2) && _tieneCuentasPorCobrar)
                                  const SizedBox(width: 12),

                                // Botón de cobro - solo mostrar si tiene cuentas por cobrar
                                if (_tieneCuentasPorCobrar)
                                  Expanded(
                                    child: CustomButton(
                                      text: _isLoadingCuentas ? 'VERIFICANDO...' : 'COBRAR',
                                      onPressed: _isLoadingCuentas ? null : () async {
                                        print('🎯 Navegando a timeline - Cliente: ${widget.clienteId}');
                                        
                                        if (_cuentaParaCobrar != null) {
                                          // Crear una copia de la cuenta con el ID correcto del cliente
                                          final cuentaCorregida = CuentasXCobrar(
                                            cpCo_Id: _cuentaParaCobrar!.cpCo_Id,
                                            clie_Id: widget.clienteId, // Usar el ID correcto del cliente
                                            fact_Id: _cuentaParaCobrar!.fact_Id,
                                            cpCo_FechaEmision: _cuentaParaCobrar!.cpCo_FechaEmision,
                                            cpCo_FechaVencimiento: _cuentaParaCobrar!.cpCo_FechaVencimiento,
                                            cpCo_Valor: _cuentaParaCobrar!.cpCo_Valor,
                                            cpCo_Saldo: _cuentaParaCobrar!.monto ?? _cuentaParaCobrar!.cpCo_Saldo, // Usar monto si está disponible
                                            cpCo_Observaciones: _cuentaParaCobrar!.cpCo_Observaciones,
                                            cpCo_Anulado: _cuentaParaCobrar!.cpCo_Anulado,
                                            cpCo_Saldada: _cuentaParaCobrar!.cpCo_Saldada,
                                            cliente: _cliente?['clie_Nombre'] ?? 'Cliente',
                                            clie_Nombres: _cliente?['clie_Nombres'] ?? '',
                                            clie_Apellidos: _cliente?['clie_Apellidos'] ?? '',
                                            monto: _cuentaParaCobrar!.monto,
                                            totalPendiente: _cuentaParaCobrar!.monto ?? _cuentaParaCobrar!.totalPendiente, // Usar monto como totalPendiente
                                          );
                                          
                                          print('💰 Cuenta corregida - Monto: ${cuentaCorregida.monto}, TotalPendiente: ${cuentaCorregida.totalPendiente}, cpCo_Saldo: ${cuentaCorregida.cpCo_Saldo}');
                                          
                                          print('💰 Navegando con cuenta corregida: ID=${cuentaCorregida.cpCo_Id}, Cliente=${cuentaCorregida.clie_Id}, Monto=${cuentaCorregida.monto}');
                                          // Navegar y esperar el resultado para refrescar si es necesario
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CuentasPorCobrarDetailsScreen(
                                                cuentaId: widget.clienteId, // Usar el ID del cliente, no de la cuenta específica
                                                cuentaResumen: cuentaCorregida,
                                              ),
                                            ),
                                          );
                                          
                                          // Si regresa de la pantalla, refrescar los datos
                                          if (result == true || result == null) {
                                            print('🔄 Regresando de pantalla de cuentas - refrescando datos...');
                                            await _verificarCuentasPorCobrar();
                                          }
                                        } else {
                                          // Fallback: obtener timeline y usar la primera cuenta encontrada
                                          print('🔄 No hay cuenta específica, obteniendo timeline para encontrar una cuenta...');
                                          _navegarConPrimeraCuenta();
                                        }
                                      },
                                      height: 50,
                                      fontSize: 14,
                                      icon: Icon(
                                        _isLoadingCuentas ? Icons.hourglass_empty : Icons.monetization_on,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        const SizedBox(
                          height: 24,
                        ), // Espacio adicional al final
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Construye un avatar por defecto cuando no hay imagen del cliente
  Widget _buildDefaultAvatar() {
    return const Icon(
      Icons.person,
      size: 50,
      color: Colors.grey,
    );
  }
}
