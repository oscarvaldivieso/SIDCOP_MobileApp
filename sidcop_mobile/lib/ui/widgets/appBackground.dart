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
              Container(
                width: MediaQuery.of(context).size.width * 0.5,
                height: MediaQuery.of(context).size.width * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF141A2F),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned.fill(
                      child: Transform.flip(
                        flipX: true,
                        child: ClipOval(
                          child: SvgPicture.asset(
                            'BreadCrumSVG2.svg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    // Title centered
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          title,
                          style: titleStyle ??
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Icon positioned at the bottom center
                    Align(
                      alignment: const Alignment(0, 0.6),
                      child: Icon(
                        icon,
                        color: iconColor ?? const Color(0xFFE0C7A0),
                        size: iconSize ?? 48,
                      ),
                    ),
                  ],
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
