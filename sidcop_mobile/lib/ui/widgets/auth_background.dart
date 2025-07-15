import 'package:flutter/material.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
    Widget build(BuildContext context) {
      return Stack(
          children: [
            Positioned(
              top: -900,
              left: -980,
              child: Image.asset(
                'assets/Ellipse 3.png',
                width: 2000,
                height: 2000,
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 400,
              left: MediaQuery.of(context).size.width / 2 - 400,
              child: Image.asset(
                'assets/Ellipse 3.png',
                width: 800,
                height: 800,
              ),
            ),
            Positioned(
              bottom: -900,
              right: -1000,
              child: Transform.rotate(
                angle: 4 * math.pi / 3,
                child: Image.asset(
                  'assets/Ellipse 3.png',
                  width: 2200,
                  height: 2200,
                ),
              ),
            ),
          ],
        );
    }
}