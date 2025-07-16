import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final Widget? icon;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height = 56,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w700,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = width ?? screenWidth * 0.7;

    return Center(
      child: Container(
        width: buttonWidth,
        height: height,
        padding: const EdgeInsets.all(2), // margen para que el borde se vea
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFD6B68A),
              Color(0xFF98774A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF262B40), // color interno del botón
            borderRadius: BorderRadius.circular(height / 2 - 2),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(height / 2 - 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(height / 2 - 2),
              onTap: onPressed,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                        fontFamily: 'Satoshi',
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 12),
                      icon!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
