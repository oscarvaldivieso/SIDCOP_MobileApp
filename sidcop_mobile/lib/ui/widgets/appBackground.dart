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
  final List<dynamic> permisos;
  final Future<void> Function()? onRefresh;

  const AppBackground({
    super.key,
    required this.title,
    required this.icon,
    this.iconColor,
    this.iconSize,
    this.titleStyle,
    this.child,
    this.permisos = const [],
    this.onRefresh,
  });

  //Creación del scaffold con el fondo degradado y el breadcrum en la parte superior para 
  //reutilizar en las distintas pantallas
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(),
      drawer: CustomDrawer(permisos: permisos),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF6F6F6), Color(0xFFF6F6F6)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh:
              onRefresh ??
              () async {
                await Future.delayed(const Duration(milliseconds: 500));
              },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height * 0.03,
              left: 16,
              right: 16,
              bottom: 14,
            ),
            child: Column(
              children: [
                // Breadcrumb que se mueve con el scroll
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: Container(
                    color: const Color(0xFF141A2F),
                    child: SizedBox(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.10,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Transform.flip(
                              flipX: true,
                              child: SvgPicture.asset(
                                'assets/BreadCrumSVG2.svg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Título alineado a la izquierda y centrado verticalmente
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                              ),
                              child: Text(
                                title,
                                style:
                                    titleStyle ??
                                    Theme.of(
                                      context,
                                    ).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Satoshi',
                                      fontSize: 20,
                                    ),
                              ),
                            ),
                          ),
                          // Icono alineado a la esquina inferior derecha
                          Positioned(
                            bottom: 12,
                            right: 18,
                            child: Icon(
                              icon,
                              color: iconColor ?? const Color(0xFFE0C7A0),
                              size: iconSize ?? 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (child != null) ...[const SizedBox(height: 24), child!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
