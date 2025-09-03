import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/ClientesVisitaHistorialService.dart';
import 'package:sidcop_mobile/ui/widgets/AppBackground.dart';
import 'package:sidcop_mobile/ui/widgets/custom_button.dart';

class VisitaDetailsScreen extends StatefulWidget {
  final int visitaId;
  final String clienteNombre;
  final Map<String, dynamic>? visitaData; // Para mostrar Imagenes de la visita

  const VisitaDetailsScreen({
    Key? key,
    required this.visitaId,
    required this.clienteNombre,
    this.visitaData,
  }) : super(key: key);

  @override
  _VisitaDetailsScreenState createState() => _VisitaDetailsScreenState();
}

class _VisitaDetailsScreenState extends State<VisitaDetailsScreen> {
  final ClientesVisitaHistorialService _visitaService =
      ClientesVisitaHistorialService();
  List<Map<String, dynamic>> _imagenes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarImagenes();
  }

  Future<void> _cargarImagenes() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final imagenes = await _visitaService.listarImagenesPorVisita(
        widget.visitaId,
      );

      setState(() {
        _imagenes = imagenes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar las imágenes de la visita';
        _isLoading = false;
      });
    }
  }

  void _showImageFullScreen(String imageUrl, String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Hero(
                tag: tag,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build a field with label above value (similar to ClientDetailsScreen)
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

  Widget _buildDefaultImage() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.photo_library, size: 80, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = 'http://200.59.27.115:8091';
    final primeraImagen = _imagenes.isNotEmpty
        ? _imagenes.first['imVi_Imagen'] as String?
        : null;

    return Scaffold(
      drawerScrimColor: Colors.black54,
      drawerEnableOpenDragGesture: true,
      body: Stack(
        children: [
          AppBackground(
            title: 'Imagenes de la Visita',
            icon: Icons.visibility_outlined,
            onRefresh: () async {
              await _cargarImagenes();
            },
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontFamily: 'Satoshi'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'REINTENTAR',
                          onPressed: _cargarImagenes,
                          height: 50,
                          fontSize: 14,
                          icon: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Visit Title with Back Button
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
                              const Expanded(
                                child: Text(
                                  'Imagenes de la Visita',
                                  style: TextStyle(
                                    fontFamily: 'Satoshi',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Visit Information
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
                                value: widget.clienteNombre,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),

                        // Featured Image (similar to client image)
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
                              child: primeraImagen != null
                                  ? GestureDetector(
                                      onTap: () => _showImageFullScreen(
                                        "$baseUrl$primeraImagen",
                                        'featured_image',
                                      ),
                                      child: Hero(
                                        tag: 'featured_image',
                                        child: Image.network(
                                          "$baseUrl$primeraImagen",
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width -
                                              48,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  _buildDefaultImage(),
                                        ),
                                      ),
                                    )
                                  : _buildDefaultImage(),
                            ),
                          ),
                        ),

                        // Gallery Title
                        if (_imagenes.length > 1)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                            child: Text(
                              'Galería de Imágenes',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF141A2F),
                              ),
                            ),
                          ),

                        // Image Gallery
                        if (_imagenes.length > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: _imagenes.length,
                              itemBuilder: (context, index) {
                                final imagen = _imagenes[index];
                                final tag =
                                    'gallery_image_${imagen['imVi_Id'] ?? index}';
                                final imagePath =
                                    imagen['imVi_Imagen'] as String?;

                                if (imagePath == null)
                                  return const SizedBox.shrink();

                                final imageUrl = "$baseUrl$imagePath";

                                return GestureDetector(
                                  onTap: () =>
                                      _showImageFullScreen(imageUrl, tag),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Hero(
                                      tag: tag,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                      color: Colors.grey,
                                                      size: 40,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        // Action Buttons Section (similar to ClientDetailsScreen)
                        if (_imagenes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 24.0,
                            ),
                          ),

                        // Empty state if no images
                        if (_imagenes.isEmpty &&
                            !_isLoading &&
                            _errorMessage.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.photo_library_outlined,
                                    size: 60,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No hay imágenes para esta visita',
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
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
}
