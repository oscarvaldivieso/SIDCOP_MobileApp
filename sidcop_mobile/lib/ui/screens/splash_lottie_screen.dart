import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:sidcop_mobile/ui/screens/onboarding/onboarding_screen.dart';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';
import 'package:sidcop_mobile/services/SyncService.dart';
import 'package:sidcop_mobile/services/EncryptedCsvStorageService.dart';
import 'package:sidcop_mobile/services/UsuarioService.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:async';

class SplashLottieScreen extends StatefulWidget {
  const SplashLottieScreen({super.key});

  @override
  State<SplashLottieScreen> createState() => _SplashLottieScreenState();
}

class _SplashLottieScreenState extends State<SplashLottieScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;
        _navigateToNextScreen();
      }
    });
    
    // Iniciar sincronización offline en segundo plano
    _initializeOfflineSync();
  }

  /// Inicializa la sincronización offline al arrancar la app
  Future<void> _initializeOfflineSync() async {
    try {
      developer.log('🚀 Iniciando sincronización offline...');
      
      // Verificar si hay datos existentes (operación ligera)
      final hasExistingData = await _checkExistingData();
      
      if (hasExistingData) {
        developer.log('📊 Datos existentes encontrados, iniciando sincronización...');
        
        // Verificar conexión (operación ligera)
        final hasConnection = await SyncService.hasInternetConnection();
        
        if (hasConnection) {
          developer.log('🌐 Conexión disponible, sincronizando datos en background...');
          
          // Ejecutar sincronización en un isolate separado para no bloquear UI
          _runSyncInBackground();
        } else {
          developer.log('📱 Sin conexión, usando datos offline existentes');
        }
      } else {
        developer.log('📝 No hay datos existentes, se requerirá conexión inicial');
      }
      
    } catch (e) {
      developer.log('❌ Error en sincronización inicial: $e');
    }
  }
  
  /// Ejecuta la sincronización en un isolate separado para evitar bloquear el hilo principal
  void _runSyncInBackground() {
    // Crear un puerto de recepción para comunicación con el isolate
    final receivePort = ReceivePort();
    
    // Lanzar isolate para trabajo pesado
    Isolate.spawn<SendPort>(_isolateSyncFunction, receivePort.sendPort)
      .then((isolate) {
        // Escuchar mensajes del isolate
        receivePort.listen((message) {
          if (message is bool) {
            // Resultado de la sincronización
            if (message) {
              developer.log('✅ Sincronización en background completada exitosamente');
            } else {
              developer.log('⚠️ Sincronización en background parcial o con errores');
            }
            
            // Cerrar el isolate y el puerto cuando termine
            receivePort.close();
            isolate.kill(priority: Isolate.immediate);
          }
        });
      })
      .catchError((e) {
        developer.log('❌ Error creando isolate para sincronización: $e');
        receivePort.close();
      });
  }
  
  /// Función que se ejecuta en el isolate separado
  static void _isolateSyncFunction(SendPort sendPort) async {
    try {
      // Ejecutar sincronización
      final result = await SyncService.syncAllData();
      
      // Enviar resultado de vuelta al hilo principal
      sendPort.send(result);
    } catch (e) {
      developer.log('❌ Error en isolate de sincronización: $e');
      sendPort.send(false);
    }
  }
  
  /// Verifica si existen datos offline previamente guardados
  Future<bool> _checkExistingData() async {
    try {
      // Verificar si existen archivos CSV cifrados de productos
      final products = await EncryptedCsvStorageService.loadProductsData();
      return products.isNotEmpty;
    } catch (e) {
      developer.log('Error verificando datos existentes: $e');
      return false;
    }
  }
  
  /// Navega a la siguiente pantalla después de completar la inicialización
  Future<void> _navigateToNextScreen() async {
    // Verificar si hay credenciales guardadas para auto-login
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    
    if (rememberMe && savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
      // Intentar auto-login
      try {
        final usuarioService = UsuarioService();
        final perfilUsuarioService = PerfilUsuarioService();
        
        final result = await usuarioService.iniciarSesion(savedEmail, savedPassword);
        
        if (result != null && result['error'] != true) {
          // Login exitoso - guardar datos del usuario
          await perfilUsuarioService.guardarDatosUsuario(result);
          
          // Sincronización rápida
          await SyncService.syncAfterLogin(
            immediate: false,
            onProgress: (status) {
              developer.log('Auto-login sync: $status');
            },
          );
          
          // Navegar directamente al HomeScreen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
          return;
        } else {
          // Si el auto-login falla, limpiar credenciales guardadas
          await prefs.remove('remember_me');
          await prefs.remove('saved_email');
          await prefs.remove('saved_password');
        }
      } catch (e) {
        developer.log('Error en auto-login: $e');
        // Si hay error, limpiar credenciales guardadas
        await prefs.remove('remember_me');
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }
    }
    
    // Si no hay credenciales o el auto-login falló, ir al onboarding
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181E34),
      body: Stack(
        children: [
          Center(
            child: Lottie.asset(
              'assets/Artboard_3.json',
              controller: _controller,
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              fit: BoxFit.contain,
              repeat: false,
              onLoaded: (composition) {
                _controller.duration = composition.duration;
                _controller.forward();
              },
            ),
          ),

          // Overlay para cubrir la marca de agua
          Positioned(
            right: MediaQuery.of(context).size.width * 0.0, // 10% del ancho
            bottom: MediaQuery.of(context).size.height * 0.10, // 30% del alto
            child: Container(
              width: MediaQuery.of(context).size.width * 0.40, // 40% del ancho
              height: MediaQuery.of(context).size.height * 0.15, // 15% del alto
              color: const Color.fromRGBO(
                24,
                30,
                52,
                1,
              ), // Mismo color que el fondo
            ),
          ),

          Positioned(
            bottom: 60,
            right: -100,
            child: Image.asset('assets/Ellipse1.png', width: 300, height: 300),
          ),
          Positioned(
            top: 50,
            right: -80,
            child: Image.asset('assets/Ellipse1.png', width: 150, height: 150),
          ),
          Positioned(
            top: 80,
            left: -100,
            child: Image.asset('assets/Ellipse1.png', width: 330, height: 330),
          ),
        ],
      ),
    );
  }
}
