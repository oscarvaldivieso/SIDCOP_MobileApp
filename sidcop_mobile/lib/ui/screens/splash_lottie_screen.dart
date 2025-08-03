import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:sidcop_mobile/ui/screens/onboarding/onboarding_screen.dart';

class SplashLottieScreen extends StatefulWidget {
  const SplashLottieScreen({super.key});

  @override
  State<SplashLottieScreen> createState() => _SplashLottieScreenState();
}

class _SplashLottieScreenState extends State<SplashLottieScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        // );
      }
    });
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
          // Overlay para cubrir la marca de agua (ajusta el tamaño si es necesario)
          Positioned(
           right: MediaQuery.of(context).size.width * 0.0,   // 10% del ancho
  bottom: MediaQuery.of(context).size.height * 0.10, // 30% del alto
  child: Container(
    width: MediaQuery.of(context).size.width * 0.40, // 40% del ancho
    height: MediaQuery.of(context).size.height * 0.15, // 15% del alto
    color: const Color.fromARGB(255, 255, 255, 255), // Mismo color que el fondo
            ),
          ),
        ],
      ),
    );
  }
}

