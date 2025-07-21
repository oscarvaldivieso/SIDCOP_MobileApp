import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart' show AppBarWidget;
import 'package:sidcop_mobile/ui/widgets/drawer.dart';

class AppBackground extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final double? iconSize;
  final TextStyle? titleStyle;
  final Widget? child;

  const AppBackground({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.iconSize,
    this.titleStyle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: const CustomDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F6F6), Color(0xFFF6F6F6)],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).size.height * 0.07,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Card.filled(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                color: const Color(0xFF141A2F),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.height * 0.18,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Transform.flip(
                          flipX: true,
                          child: SvgPicture.asset(
                            'BreadCrumSVG2.svg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Título alineado a la izquierda y centrado verticalmente
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            title,
                            style:
                                titleStyle ??
                                Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                      // Icono alineado abajo y más al centro
                      Align(
                        alignment: Alignment(
                          0.65,
                          0.85,
                        ), // 0.65 = más cerca del centro, 0.85 = abajo
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Icon(
                            icon,
                            color: iconColor ?? const Color(0xFFE0C7A0),
                            size: iconSize ?? 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (child != null) ...[const SizedBox(height: 24), child!],
            ],
          ),
        ),
      ),
    );
  }
}
