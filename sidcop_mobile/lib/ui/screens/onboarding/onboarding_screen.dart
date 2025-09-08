import 'package:flutter/material.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/loading_overlay.dart';
import '../auth/login_screen.dart';

class _LoginBottomSheetWrapper extends StatefulWidget {
  final Function(bool) onLoadingChanged;
  
  const _LoginBottomSheetWrapper({required this.onLoadingChanged});

  @override
  State<_LoginBottomSheetWrapper> createState() => _LoginBottomSheetWrapperState();
}

class _LoginBottomSheetWrapperState extends State<_LoginBottomSheetWrapper> {
  bool _isLoading = false;
  String _syncStatus = '';

  void _handleLoadingChange(bool isLoading, [String status = '']) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
        _syncStatus = status;
      });
      // Notificar al padre sobre el cambio de estado de carga
      widget.onLoadingChanged(isLoading);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: _isLoading ? 0.7 : 0.7, // Mantener tamaño fijo durante carga
      minChildSize: _isLoading ? 0.7 : 0.5, // Bloquear arrastre durante carga
      expand: false,
      builder: (_, controller) {
        return Stack(
          children: [
            // Absorber gestos durante carga para bloquear interacción
            if (_isLoading)
              Positioned.fill(
                child: AbsorbPointer(
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 254, 247, 255),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 30),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey[300] : Colors.grey[400], // Indicador visual de bloqueo
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: LoginScreen(
                      scrollController: controller,
                      onLoadingChanged: _handleLoadingChange,
                    ),
                  ),
                ],
              ),
            ),
            // Loading overlay que cubre toda la pantalla
            if (_isLoading)
              LoadingOverlay(
                message: 'Cargando',
                status: _syncStatus,
              ),
          ],
        );
      },
    );
  }
}


class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isModalLoading = false;

  void _handleModalLoadingChange(bool isLoading) {
    setState(() {
      _isModalLoading = isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AuthBackground(),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/logo_blanco.png', // Asegúrate que el nombre del archivo es correcto
                        height: 100,
                      ),
                      Image.asset('assets/marca_blanco.png', height: 80),
                      const SizedBox(height: 40),
                      SizedBox(
                        width:
                            280, // Un poco más ancho que la imagen marca_blanco.png (que tiene height: 80)
                        child: Text(
                          '¡Tu distribución más rápida, precisa y organizada!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: ElevatedButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled:
                              true, // ← importante para altura completa
                          backgroundColor:
                              Colors.transparent, // Para bordes redondeados
                          isDismissible: !_isModalLoading, // No se puede cerrar durante carga
                          enableDrag: !_isModalLoading, // No se puede arrastrar durante carga
                          builder: (context) {
                            return _LoginBottomSheetWrapper(
                              onLoadingChanged: _handleModalLoadingChange,
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF06115B),
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Comencemos',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w500,
                              fontSize: 22,
                              color: Color(0xFF06115B),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(0xFF98774A),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
