import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/Offline_Services/Visitas_OfflineServices.dart';
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
  List<Map<String, dynamic>> _imagenes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isOfflineVisita = false;

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

      // Verificar si es una visita offline con imágenes Base64
      if (widget.visitaData != null &&
          widget.visitaData!['offline'] == true &&
          widget.visitaData!['imagenesBase64'] != null) {
        _isOfflineVisita = true;
        final List<dynamic> imagenesBase64 =
            widget.visitaData!['imagenesBase64'];

        if (imagenesBase64.isNotEmpty) {
          // Convertir las imágenes Base64 a un formato que la UI pueda usar
          List<Map<String, dynamic>> imagenesFormateadas = [];

          for (int i = 0; i < imagenesBase64.length; i++) {
            imagenesFormateadas.add({
              'imVi_Id': i, // ID interno para identificar la imagen
              'base64_data': imagenesBase64[i], // Datos Base64 de la imagen
              'es_offline': true,
            });
          }

          setState(() {
            _imagenes = imagenesFormateadas;
            _isLoading = false;
          });
          return;
        }
      }

      // Si no es offline o no tiene imágenes Base64, cargar desde almacenamiento local
      final imagenes = await VisitasOffline.obtenerImagenesVisitaLocal(
        widget.visitaId,
      );

      if (imagenes != null && imagenes.isNotEmpty) {
        setState(() {
          _imagenes = imagenes;
          _isLoading = false;
        });
      } else {
        // Si no hay imágenes guardadas localmente, mostrar un mensaje amigable
        setState(() {
          _errorMessage = 'No hay imágenes disponibles para esta visita';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar las imágenes de la visita';
        _isLoading = false;
      });
    }
  }

  void _showImageFullScreen(
    String imageUrl,
    String tag, {
    String? rutaLocal,
    String? base64Data,
  }) {
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
                child: base64Data != null
                    ? Image.memory(
                        base64Decode(base64Data),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 60,
                          ),
                        ),
                      )
                    : rutaLocal != null
                    ? Image.file(
                        File(rutaLocal),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Si la imagen local falla, intenta cargar desde la red
                          return Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 60,
                                  ),
                                ),
                          );
                        },
                      )
                    : Image.network(
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

  // Construye un campo con etiqueta sobre el valor (similar a ClientDetailsScreen)
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

  // Método que construye una imagen con fallback de red a local o viceversa, o Base64 para offline
  Widget _buildImageWithFallback(
    Map<String, dynamic> imagen,
    String baseUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    final rutaLocal = imagen['ruta_local'] as String?;
    final rutaRemota = imagen['imVi_Imagen'] as String?;
    final base64Data = imagen['base64_data'] as String?;
    final esOffline = imagen['es_offline'] == true;

    // Si tenemos datos Base64 (caso de visitas offline), usar esa imagen
    if (base64Data != null && esOffline) {
      try {
        return Image.memory(
          base64Decode(base64Data),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultImage();
          },
        );
      } catch (e) {
        return _buildDefaultImage();
      }
    } else if (rutaLocal != null) {
      // Primero intentamos mostrar la imagen local
      return Image.file(
        File(rutaLocal),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Si falla la imagen local, intentamos con la remota
          if (rutaRemota != null) {
            return Image.network(
              "$baseUrl$rutaRemota",
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultImage(),
            );
          } else {
            return _buildDefaultImage();
          }
        },
      );
    } else if (rutaRemota != null) {
      // Si no hay ruta local, intentamos con la remota directamente
      return Image.network(
        "$baseUrl$rutaRemota",
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildDefaultImage(),
      );
    } else {
      // Si no hay ninguna ruta, mostramos la imagen por defecto
      return _buildDefaultImage();
    }
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
                        // Título de la Visita con Botón de Regreso
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

                        // Información de la Visita
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

                        // Imagen Destacada (similar a la imagen del cliente)
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
                                      onTap: () {
                                        // Verificar si hay ruta local disponible
                                        final rutaLocal = _imagenes.isNotEmpty
                                            ? _imagenes.first['ruta_local']
                                                  as String?
                                            : null;

                                        // Verificar si hay datos Base64 disponibles
                                        final base64Data = _imagenes.isNotEmpty
                                            ? _imagenes.first['base64_data']
                                                  as String?
                                            : null;

                                        _showImageFullScreen(
                                          "$baseUrl$primeraImagen",
                                          'featured_image',
                                          rutaLocal: rutaLocal,
                                          base64Data: base64Data,
                                        );
                                      },
                                      child: Hero(
                                        tag: 'featured_image',
                                        child: _buildImageWithFallback(
                                          _imagenes.first,
                                          baseUrl,
                                          width:
                                              MediaQuery.of(
                                                context,
                                              ).size.width -
                                              48,
                                          height: 200,
                                        ),
                                      ),
                                    )
                                  : _buildDefaultImage(),
                            ),
                          ),
                        ),

                        // Título de la Galería
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

                        // Galería de Imágenes
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
                                final rutaLocal =
                                    imagen['ruta_local'] as String?;
                                final base64Data =
                                    imagen['base64_data'] as String?;

                                if (imagePath == null &&
                                    rutaLocal == null &&
                                    base64Data == null)
                                  return const SizedBox.shrink();

                                final imageUrl = imagePath != null
                                    ? "$baseUrl$imagePath"
                                    : '';

                                return GestureDetector(
                                  onTap: () => _showImageFullScreen(
                                    imageUrl,
                                    tag,
                                    rutaLocal: rutaLocal,
                                    base64Data: base64Data,
                                  ),
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
                                        child: _buildImageWithFallback(
                                          imagen,
                                          baseUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                        // Espacio adicional para separar la galería del final
                        if (_imagenes.isNotEmpty) const SizedBox(height: 24),

                        // Estado vacío si no hay imágenes
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
