import 'package:flutter/material.dart';
import '../../widgets/auth_background.dart';
import '../auth/login_screen.dart';

class _LoginBottomSheet extends StatelessWidget {
  const _LoginBottomSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.7,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) {
        return Container(
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
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: LoginScreen(scrollController: controller)),
            ],
          ),
        );
      },
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

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
                          builder: (context) {
                            return const _LoginBottomSheet(); // Creamos este widget abajo
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
