import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/auth-background.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: const Color.fromARGB(204, 25, 26, 46), // #06115B, 50% opacity
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}