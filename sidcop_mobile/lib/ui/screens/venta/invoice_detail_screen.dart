import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/VentaService.dart';
import 'package:sidcop_mobile/services/printer_service.dart';
import 'package:sidcop_mobile/services/GlobalService.dart';
import 'generateInvoicePdf.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sidcop_mobile/Offline_Services/Ventas_OfflineService.dart';
import 'package:sidcop_mobile/ui/screens/venta/ventas_list_screen.dart';



class InvoiceDetailScreen extends StatefulWidget {
  final int facturaId;
  final String facturaNumero;
  final bool fromVentasList;

  const InvoiceDetailScreen({
    Key? key,
    required this.facturaId,
    required this.facturaNumero,
    this.fromVentasList = false,
  }) : super(key: key);

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

// Clase para crear el efecto de factura rota
class TornPaperClipper extends CustomClipper<Path> {
  final double jaggedness = 20.0;

  @override
  Path getClip(Size size) {
    var path = Path();
    // Inicia en la esquina superior izquierda
    path.lineTo(0, 0);

    // Dibuja la parte superior con picos irregulares
    var i = 0.0;
    while (i < size.width) {
      path.lineTo(i + jaggedness / 2, jaggedness);
      path.lineTo(i + jaggedness, 0);
      i += jaggedness;
    }

    // Dibuja el resto de los bordes rectos
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(TornPaperClipper oldClipper) => true;
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final VentaService _ventaService = VentaService();
  final PrinterService _printerService = PrinterService();
  
  Map<String, dynamic>? _facturaData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Si el ID es negativo, buscar solo offline
      if (widget.facturaId < 0) {
        print('[DEBUG] Cargando factura offline con ID: ${widget.facturaId}');
        final facturaOffline = await VentasOfflineService.obtenerFacturaCompletaOffline(widget.facturaId);
        if (facturaOffline != null) {
          setState(() {
            _facturaData = facturaOffline;
            _isLoading = false;
            _error = null;
          });
        } else {
          setState(() {
            _error = 'No se encontró la factura offline';
            _isLoading = false;
          });
        }
        return;
      }

      final response = await _ventaService.obtenerFacturaCompleta(widget.facturaId);

      if (response != null && response['success'] == true) {
        setState(() {
          _facturaData = response['data'];
          _isLoading = false;
        });
        // Guardar detalle de factura offline
        await VentasOfflineService.guardarFacturaCompletaOffline(widget.facturaId, _facturaData!);
      } else {
        // Si falla la consulta online, intentar leer factura offline
        final facturaOffline = await VentasOfflineService.obtenerFacturaCompletaOffline(widget.facturaId);
        if (facturaOffline != null) {
          setState(() {
            _facturaData = facturaOffline;
            _isLoading = false;
            _error = null;
          });
        } else {
          setState(() {
            _error = response?['message'] ?? 'Error al cargar la factura';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Si hay error de conexión, intentar leer factura offline
      final facturaOffline = await VentasOfflineService.obtenerFacturaCompletaOffline(widget.facturaId);
      if (facturaOffline != null) {
        setState(() {
          _facturaData = facturaOffline;
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Error inesperado: $e';
          _isLoading = false;
        });
      }
    }
  }

  //Metodo para mostrar las opciones de impresion
  void _showPrintOptions() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador visual del modal
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Título con icono
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.print,
                size: 28,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 12),
              Text(
                'Opciones de Impresión',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Satoshi',
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Text(
            'Selecciona el tipo de documento a imprimir',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Satoshi',
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 32),
          
          // Botones de opciones
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                        _printInvoice(isOriginal: true);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade600, Colors.blue.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade200.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ORIGINAL',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Satoshi',
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Documento oficial',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Satoshi',
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                        _printInvoice(isOriginal: false);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey.shade500, Colors.grey.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade300.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.content_copy,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'COPIA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Satoshi',
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Para archivo',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Satoshi',
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Botón de cancelar
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'CANCELAR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Satoshi',
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          
          // Espacio adicional para dispositivos con notch
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 8),
        ],
      ),
    ),
  );
}

  //Metodo para imprimir la factura - OPTIMIZADO
  Future<void> _printInvoice({required bool isOriginal}) async {
    if (_facturaData == null) return;

    try {
      // Usar el nuevo método optimizado con reconexión automática
      final printSuccess = await _printerService.printWithAutoConnect(
        context,
        () async {
          // Función de impresión
          return await _printerService.printInvoice(
            _facturaData!,
            isOriginal: isOriginal,
          );
        },
        loadingMessage: 'Preparando impresión de factura...',
      );
      
      if (mounted) {
        if (printSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Factura impresa exitosamente'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Error al imprimir la factura'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al imprimir: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF141A2F),
              const Color(0xFF1A2238),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 70,
          leading: Container(
            margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color.fromARGB(255, 160, 148, 83).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () {
                if (widget.fromVentasList) {
                  // Si venimos de la lista de ventas, simplemente volvemos atrás
                  Navigator.pop(context);
                } else {
                  // Si venimos de crear una nueva venta, volvemos a la lista de ventas
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VentasListScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              tooltip: 'Regresar',
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Factura',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Botón de imprimir
            Container(
              margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: _showPrintOptions,
                icon: const Icon(
                  Icons.print_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Imprimir',
              ),
            ),
            
            // Botón de compartir
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Builder(
                builder: (context) => IconButton(
                  onPressed: () => _showFloatingShareMenu(context),
                  icon: const Icon(
                    Icons.share_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Compartir',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF98BF4A),
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _buildInvoiceContent(),
    );
  }

  //Metodo para compartir la factura
  void _showFloatingShareMenu(BuildContext context) async {
    if (_facturaData == null) return;

    final pdfFile = await generateInvoicePdf(_facturaData!, widget.facturaNumero);

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = context.findRenderObject() as RenderBox;
    final buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  overlayEntry.remove();
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
            Positioned(
              left: buttonPosition.dx + button.size.width - 180,
              top: buttonPosition.dy + 60,
              child: Material(
                color: Colors.transparent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconButton(
                      icon: FontAwesomeIcons.whatsapp,
                      color: Colors.green,
                      onPressed: () async {
                        await Share.shareXFiles([XFile(pdfFile.path)], text: "Factura SIDCOP");
                        overlayEntry.remove();
                      },
                    ),
                    _buildIconButton(
                      icon: FontAwesomeIcons.filePdf,
                      color: const Color.fromARGB(255, 117, 19, 12),
                      onPressed: () {
                        overlayEntry.remove();
                        _showDownloadProgress(pdfFile);
                      },
                    ),
                    _buildIconButton(
                      icon: Icons.more_horiz,
                      color: Colors.grey,
                      onPressed: () async {
                        await Share.shareXFiles([XFile(pdfFile.path)], text: "Factura SIDCOP");
                        overlayEntry.remove();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(overlayEntry);
  }


  Widget _buildIconButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: CircleAvatar(
          backgroundColor: const Color.fromARGB(255, 248, 248, 248),
          radius: 24,
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }


  void _showDownloadProgress(File pdfFile) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Selecciona la carpeta para guardar el PDF',
    );

    if (selectedDirectory == null) {
      return;
    }

    final fileName = pdfFile.path.split(Platform.pathSeparator).last;
    final newPath = '$selectedDirectory${Platform.pathSeparator}$fileName';
    await pdfFile.copy(newPath);

    double progress = 0.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (progress < 1.0) {
                setState(() => progress += 0.25);
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Factura descargada en: $newPath")),
                );
              }
            });

            return AlertDialog(
              title: const Text("Descargando..."),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text("${(progress * 100).toInt()}%"),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar la factura',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontFamily: 'Satoshi',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadInvoiceDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF98BF4A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tu widget principal con la corrección
  Widget _buildInvoiceContent() {
    if (_facturaData == null) return const SizedBox();

    final factura = _facturaData!;

    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 255, 255),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipPath(
          clipper: TornPaperClipper(),
          child: Column(
            children: [
              // Agrega un padding superior aquí
              Padding(
                padding: const EdgeInsets.only(top: 0), // Ajusta este valor
                child: _buildCompanyHeader(factura),
              ),
              _buildInvoiceHeader(factura),
              _buildProductsTable(factura),
              _buildTotalsSection(factura),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildCompanyHeader(Map<String, dynamic> factura) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(
        bottom: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
    ),
    child: Column(
      children: [
        // Logo centrado
        Container(
          width: 70,
          height: 70,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: factura['coFa_Logo'] != null && 
                 factura['coFa_Logo'].toString().isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '$apiServer/${factura['coFa_Logo']}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => 
                    _buildDefaultLogo(),
                ),
              )
            : _buildDefaultLogo(),
        ),
        
        // Nombre de la empresa centrado
        Text(
          factura['coFa_NombreEmpresa'] ?? 'Empresa',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 0, 0, 0),
            fontFamily: 'Satoshi',
            height: 1.2,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // Casa Matriz centrada
        const Text(
          'CASA MATRIZ',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color.fromARGB(255, 0, 0, 0),
            fontFamily: 'Satoshi',
            letterSpacing: 0.5,
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Dirección centrada
        if (factura['coFa_DireccionEmpresa']?.toString().trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              factura['coFa_DireccionEmpresa'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(255, 0, 0, 0),
                fontFamily: 'Satoshi',
                height: 1.3,
              ),
            ),
          ),
        
        // Teléfono centrado
        if (factura['coFa_Telefono1']?.toString().trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Tel: ${factura['coFa_Telefono1']}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(255, 0, 0, 0),
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        
        // Correo centrado
        if (factura['coFa_Correo']?.toString().trim().isNotEmpty == true)
          Text(
            factura['coFa_Correo'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color.fromARGB(255, 0, 0, 0),
              fontFamily: 'Satoshi',
            ),
          ),
      ],
    ),
  );
}

// Widget auxiliar para el logo por defecto
Widget _buildDefaultLogo() {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF98BF4A).withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Center(
      child: Icon(
        Icons.business_outlined,
        color: Color(0xFF98BF4A),
        size: 28,
      ),
    ),
  );
}

  Widget _buildInvoiceHeader(Map<String, dynamic> factura) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          // CAI
          _buildHeaderRow('CAI:', factura['regC_Descripcion'] ?? 'N/A'),
          
          // Número de factura
          _buildHeaderRow('No. Factura:', factura['fact_Numero'] ?? 'N/A'),
          
          // Fecha de emisión
          _buildHeaderRow('Fecha de Emisión:', _formatDate(factura['fact_FechaEmision'])),
          
          // Tipo de venta
          _buildHeaderRow('Tipo de Venta:', factura['fact_TipoVenta'] == 'CR' ? 'Crédito' : factura['fact_TipoVenta'] == 'CO' ? 'Contado' : 'N/A'),
          
          // Cliente
          _buildHeaderRow('Cliente:', factura['cliente'] ?? 'Cliente General'),

          // RTN del  Cliente
          _buildHeaderRow('RTN Cliente:', factura['clie_RTN'] ?? 'Cliente General'),
          
          // Direccion del  Cliente
          _buildHeaderRow('RTN Cliente:', factura['diCl_DireccionExacta'] ?? 'Cliente General'),

          // Vendedor
          _buildHeaderRow('Vendedor:', factura['vendedor'] ?? 'N/A'),

          // Vendedor
          _buildHeaderRow('No Orden de compra exenta:', '' ?? 'N/A'),

          // Vendedor
          _buildHeaderRow('No Constancia de reg de exonerados:', '' ?? 'N/A'),

          // Vendedor
          _buildHeaderRow('No Registro de la SAG:', '' ?? 'N/A'),
          
          // Línea divisoria
          Container(
            height: 1,
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            color: const Color(0xFFE9ECEF),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Tabla de detalle de los productos de la venta
  Widget _buildProductsTable(Map<String, dynamic> factura) {
    final detalles = factura['detalleFactura'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE9ECEF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header de la tabla
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF141A2F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'DESCRIPCIÓN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    'CANT.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'PRECIO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Filas de productos adaptadas para móvil
          ...detalles.asMap().entries.map((entry) {
            final index = entry.key;
            final detalle = entry.value;
            final isLast = index == detalles.length - 1;
            
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: index.isEven ? Colors.white : const Color(0xFFFAFAFA),
                border: !isLast ? const Border(
                  bottom: BorderSide(color: Color(0xFFE9ECEF), width: 0.5),
                ) : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Descripción del producto
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detalle['prod_Descripcion'] ?? 'Producto',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF141A2F),
                            fontFamily: 'Satoshi',
                          ),
                        ),
                        if (detalle['prod_CodigoBarra']?.toString().isNotEmpty == true)
                          Text(
                            'Código: ${detalle['prod_CodigoBarra']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontFamily: 'Satoshi',
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Cantidad
                  SizedBox(
                    width: 50,
                    child: Text(
                      (detalle['faDe_Cantidad'] ?? 0).toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF141A2F),
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                  
                  // Precio
                  SizedBox(
                    width: 70,
                    child: Text(
                      'L ${(detalle['faDe_PrecioUnitario'] ?? 0).toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF141A2F),
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                  
                  // Total
                  SizedBox(
                    width: 70,
                    child: Text(
                      'L ${(detalle['faDe_Subtotal'] ?? 0).toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF141A2F),
                        fontFamily: 'Satoshi',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(Map factura) {
  final subtotal = (factura['fact_Subtotal'] ?? 0.0).toDouble();
  final totalDescuento = (factura['fact_TotalDescuento'] ?? 0.0).toDouble();
  final importeExento = (factura['fact_ImporteExento'] ?? 0.0).toDouble();
  final importeExonerado = (factura['fact_ImporteExonerado'] ?? 0.0).toDouble();
  final importeGravado15 = (factura['fact_ImporteGravado15'] ?? 0.0).toDouble();
  final importeGravado18 = (factura['fact_ImporteGravado18'] ?? 0.0).toDouble();
  final impuesto15 = (factura['fact_TotalImpuesto15'] ?? 0.0).toDouble();
  final impuesto18 = (factura['fact_TotalImpuesto18'] ?? 0.0).toDouble();
  final total = (factura['fact_Total'] ?? 0.0).toDouble();

  return Container(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Línea divisoria
        Container(
          height: 1,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          color: Colors.grey[400],
        ),

        // Subtotal
        _buildTotalRow('Subtotal:', subtotal.toStringAsFixed(2)),

        // Descuento
        _buildTotalRow('Total Descuento:', totalDescuento.toStringAsFixed(2), isNegative: true),

        // Importe Exento
        _buildTotalRow('Importe Exento:', importeExento.toStringAsFixed(2)),

        // Importe Exonerado
        _buildTotalRow('Importe Exonerado:', importeExonerado.toStringAsFixed(2)),

        // Importe Gravado 15%
        _buildTotalRow('Importe Gravado 15%:', importeGravado15.toStringAsFixed(2)),

        // Importe Gravado 18%
        _buildTotalRow('Importe Gravado 18%:', importeGravado18.toStringAsFixed(2)),

        // ISV 15%
        _buildTotalRow('Total Impuesto 15%:', impuesto15.toStringAsFixed(2)),

        // ISV 18%
        _buildTotalRow('Total Impuesto 18%:', impuesto18.toStringAsFixed(2)),

        // Línea divisoria antes del total
        Container(
          height: 1,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.grey[400],
        ),

        // Total final
        _buildTotalRow('Total:', total.toStringAsFixed(2), isFinal: true),
      ],
    ),
  );
}


  //Totales calculados
  Widget _buildTotalRow(String label, String value, {bool isFinal = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isFinal ? 16 : 14,
                fontWeight: isFinal ? FontWeight.bold : FontWeight.w500,
                color: const Color(0xFF141A2F),
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isFinal ? 18 : 14,
              fontWeight: isFinal ? FontWeight.bold : FontWeight.w600,
              color: isFinal 
                ? const Color.fromARGB(255, 0, 0, 0)
                : isNegative
                  ? const Color.fromARGB(255, 0, 0, 0)
                  : const Color(0xFF141A2F),
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDotsLoading extends StatefulWidget {
  const _VerticalDotsLoading({Key? key}) : super(key: key);

  @override
  State<_VerticalDotsLoading> createState() => _VerticalDotsLoadingState();
}

class _VerticalDotsLoadingState extends State<_VerticalDotsLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _animation1 = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)));
    _animation2 = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.8, curve: Curves.easeIn)));
    _animation3 = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.9, curve: Curves.easeIn)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(opacity: _animation1, child: _dot()),
        const SizedBox(height: 8),
        FadeTransition(opacity: _animation2, child: _dot()),
        const SizedBox(height: 8),
        FadeTransition(opacity: _animation3, child: _dot()),
      ],
    );
  }

  Widget _dot() => Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFF141A2F),
          shape: BoxShape.circle,
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}