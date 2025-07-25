import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesService.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/client_location_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ClientdetailsScreen extends StatefulWidget {
  final int clienteId;
  
  const ClientdetailsScreen({
    super.key, 
    required this.clienteId,
  });

  @override
  State<ClientdetailsScreen> createState() => _ClientdetailsScreenState();
}

class _ClientdetailsScreenState extends State<ClientdetailsScreen> {
  final ClientesService _clientesService = ClientesService();
  Map<String, dynamic>? _cliente;
  List<dynamic> _direcciones = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCliente();
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

  Widget _buildInfoRow(String label, String? value) {
    final displayValue = value?.isNotEmpty == true ? value! : 'No especificado';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF141A2F)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          AppBackground(
            title: 'Detalles del Cliente',
            icon: Icons.person_outline,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _cliente == null
                        ? const Center(child: Text('No se encontró información del cliente'))
                        : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Client Name
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                              child: Text(
                                '${_cliente!['clie_Nombres'] ?? ''} ${_cliente!['clie_Apellidos'] ?? ''}'.trim(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            // Client Image
                            Center(
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.9,
                                height: 200,
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF141A2F),
                                    width: 2,
                                  ),
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
                                      ? CachedNetworkImage(
                                          imageUrl: _cliente!['clie_ImagenDelNegocio'],
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Center(
                                            child: SizedBox(
                                              width: 40,
                                              height: 40,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => _buildDefaultAvatar(),
                                        )
                                      : _buildDefaultAvatar(),
                                ),
                              ),
                            ),

                            // Business Info
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Información del Negocio',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF141A2F),
                                    ),
                                  ),
                                  const Divider(color: Colors.grey),
                                  _buildInfoRow('Negocio:', _cliente!['clie_NombreNegocio']),
                                  _buildInfoRow('Teléfono:', _cliente!['clie_Telefono']),
                                  _buildInfoRow('Ruta:', _cliente!['ruta_Descripcion']),
                                  if (_direcciones.isNotEmpty) ..._buildDirecciones(),
                                ],
                              ),
                            ),

                            // Client Details Card
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Información del Cliente',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF141A2F),
                                    ),
                                  ),
                                  const Divider(color: Colors.grey),
                                  _buildInfoRow('Código:', _cliente!['clie_Codigo']),
                                  _buildInfoRow('DNI:', _cliente!['clie_DNI']),
                                  _buildInfoRow('RTN:', _cliente!['clie_RTN']),
                                  _buildInfoRow('Correo:', _cliente!['clie_Correo']),
                                  _buildInfoRow('Sexo:', _cliente!['clie_Sexo']),
                                  _buildInfoRow('Límite de Crédito:', 
                                      'L. ${(_cliente!['clie_LimiteCredito'] ?? 0).toStringAsFixed(2)}'),
                                  _buildInfoRow('Días de Crédito:', 
                                      '${_cliente!['clie_DiasCredito'] ?? '0'} días'),
                                ],
                              ),
                            ),

                            // Ir a la Ubicación Button
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _direcciones.isNotEmpty
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ClientLocationScreen(
                                                locations: List<Map<String, dynamic>>.from(_direcciones),
                                                clientName: _cliente?['clie_Nombre'] ?? 'Cliente',
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Color(0xFF141A2F)),
                                    ),
                                  ),
                                  icon: const Icon(Icons.location_on, color: Color(0xFF141A2F)),
                                  label: const Text(
                                    'Ir a la ubicación',
                                    style: TextStyle(
                                      color: Color(0xFF141A2F),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 100), // Espacio para los botones flotantes
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
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implementar lógica de venta
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141A2F),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                          label: const Text(
                            'VENDER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implementar lógica de cobro
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141A2F),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                          label: const Text(
                            'COBRAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
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

  List<Widget> _buildDirecciones() {
    if (_direcciones.isEmpty) {
      return [];
    }
    
    // Tomar solo la primera dirección
    final direccion = _direcciones.first;
    return [
      _buildInfoRow('Dirección:', direccion['diCl_DireccionExacta']?.toString() ?? 'No especificada')
    ];
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.person,
          size: 80,
          color: Colors.grey,
        ),
      ),
    );
  }
}