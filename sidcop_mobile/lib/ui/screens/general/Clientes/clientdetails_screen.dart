import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/client_location_screen.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/ui/screens/pedidos/pedidos_screen.dart';

class ClientdetailsScreen extends StatefulWidget {
  final int clienteId;

  const ClientdetailsScreen({super.key, required this.clienteId});

  @override
  State<ClientdetailsScreen> createState() => _ClientdetailsScreenState();
}

class _ClientdetailsScreenState extends State<ClientdetailsScreen> {
  final ClientesService _clientesService = ClientesService();
  Map<String, dynamic>? _cliente;
  List<dynamic> _direcciones = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _vendTipo;

  @override
  void initState() {
    super.initState();
    _loadCliente();
    _loadTipoVendedor();
  }

  Future<void> _loadTipoVendedor() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    setState(() {
      _vendTipo = userData?['datosVendedor']?['vend_Tipo'] ?? userData?['vend_Tipo'];
    });
  }

  Future<void> _loadCliente() async {
    try {
      final cliente = await _clientesService.getClienteById(widget.clienteId);
      setState(() {
        _cliente = cliente;
      });
      await _loadDireccionesCliente();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar los datos del cliente';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDireccionesCliente() async {
    if (!mounted) return;

    try {
      final direcciones = await _clientesService.getDireccionesPorCliente();

      final direccionesFiltradas = direcciones.where((dir) {
        final clienteId = dir['clie_Id'];
        return clienteId == widget.clienteId;
      }).toList();

      if (mounted) {
        setState(() {
          _direcciones = direccionesFiltradas;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error cargando direcciones: ${e.toString()}';
        });
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AppBackground(
            title: 'Detalles del Cliente',
            icon: Icons.person_outline,
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
                        // Client Name with Back Button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  size: 24,
                                  color: Color(0xFF141A2F),
                                ),
                              ),
                              const SizedBox(width: 16),
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

                        // Client Image
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
                              child: _cliente!['clie_ImagenDelNegocio'] != null
                                  ? Image.network(
                                      _cliente!['clie_ImagenDelNegocio'],
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildDefaultAvatar(),
                                    )
                                  : _buildDefaultAvatar(),
                            ),
                          ),
                        ),

                        // Client Information
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cliente
                              _buildInfoField(
                                label: 'Cliente:',
                                value:
                                    '${_cliente!['clie_Nombres'] ?? ''} ${_cliente!['clie_Apellidos'] ?? ''}'
                                        .trim(),
                              ),
                              const SizedBox(height: 12),

                              // RTN
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

                              // Correo
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

                              // Teléfono
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

                              // Ruta
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

                        // Ir a la Ubicación Button
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Opacity(
                            opacity: _direcciones.isNotEmpty ? 1.0 : 0.5,
                            child: AbsorbPointer(
                              absorbing: _direcciones.isEmpty,
                              child: CustomButton(
                                text: 'IR A LA UBICACIÓN',
                                onPressed: () {
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
                        const SizedBox(
                          height: 100,
                        ), // Espacio para los botones flotantes
                      ],
                    ),
                  ),
          ),
          // Sticky Action Buttons
          if (_cliente != null && !_isLoading && _errorMessage.isEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: _vendTipo == "P"
                              ? "PEDIDO"
                              : _vendTipo == "V"
                                  ? "VENTA"
                                  : "ACCIÓN",
                          onPressed: () {
                            if (_vendTipo == "P") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PedidosScreen(),
                                ),
                              );
                            } else {
                              // TODO: Implementar lógica de venta u otra acción
                            }
                          },
                          height: 50,
                          fontSize: 14,
                          icon: Icon(
                            _vendTipo == "P"
                                ? Icons.assignment
                                : _vendTipo == "V"
                                    ? Icons.shopping_cart
                                    : Icons.help_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomButton(
                          text: 'COBRAR',
                          onPressed: () {
                            // TODO: Implementar lógica de cobro
                          },
                          height: 50,
                          fontSize: 14,
                          icon: const Icon(
                            Icons.monetization_on,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.person, size: 80, color: Colors.grey),
      ),
    );
  }
}
