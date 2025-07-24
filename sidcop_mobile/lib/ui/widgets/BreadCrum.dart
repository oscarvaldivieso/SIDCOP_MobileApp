import 'package:flutter/material.dart';

class BreadCrum extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final double? iconSize;
  final TextStyle? titleStyle;

  const BreadCrum({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor = const Color(0xFFE0C7A0), // Default gold color
    this.iconSize = 32,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF141A2F), // Dark background color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Rounded corners
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
        height: MediaQuery.of(context).size.height * 0.18, // 18% of screen height
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          gradient: LinearGradient(
            colors: [Color(0xFF1E2A4A), Color(0xFF141A2F)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Stack(
          children: [
            // Background SVG could be added here
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: Opacity(
                  opacity: 0.1,
                  child: Transform.scale(
                    scaleX: -1, // Horizontal flip
                    child: Icon(
                      icon,
                      size: 120,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: titleStyle ?? 
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
