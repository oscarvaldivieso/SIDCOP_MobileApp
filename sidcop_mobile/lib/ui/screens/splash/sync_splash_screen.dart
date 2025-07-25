import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/SyncService.dart';
import '../onboarding/onboarding_screen.dart';

class SyncSplashScreen extends StatefulWidget {
  const SyncSplashScreen({super.key});

  @override
  State<SyncSplashScreen> createState() => _SyncSplashScreenState();
}

class _SyncSplashScreenState extends State<SyncSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _statusMessage = 'Iniciando aplicación...';
  bool _hasConnection = false;
  bool _syncCompleted = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Verificar conectividad
      setState(() {
        _statusMessage = 'Verificando conexión...';
      });

      await Future.delayed(const Duration(milliseconds: 800));
      _hasConnection = await SyncService.hasInternetConnection();

      if (_hasConnection) {
        // Ejecutar sincronización
        setState(() {
          _statusMessage = 'Sincronizando datos...';
        });

        await Future.delayed(const Duration(milliseconds: 500));
        await SyncService.syncAllData();

        setState(() {
          _statusMessage = 'Sincronización completada';
          _syncCompleted = true;
        });

        await Future.delayed(const Duration(milliseconds: 1000));
      } else {
        setState(() {
          _statusMessage = 'Sin conexión - Modo offline';
        });

        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error en sincronización - Continuando...';
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      print("Error en sincronización automática: $e");
    }

    // Navegar a la pantalla principal
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A), // Azul oscuro similar al de UserInfoScreen
              Color(0xFF3B82F6), // Azul más claro
            ],
          ),
        ),
        child: Stack(
          children: [
            // Fondo SVG decorativo
            Positioned.fill(
              child: Transform.flip(
                flipX: true,
                child: SvgPicture.asset(
                  'assets/FondoNuevo2.svg',
                  fit: BoxFit.cover,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

            // Contenido principal
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo o ícono de la app
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sync,
                          size: 60,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Título de la app
                      Text(
                        'SIDCOP',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Indicador de carga
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Mensaje de estado
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      // Indicador de conexión
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasConnection ? Icons.wifi : Icons.wifi_off,
                            color: _hasConnection
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _hasConnection ? 'Conectado' : 'Sin conexión',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Información de versión en la parte inferior
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  'Distribuidora La Roca',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
