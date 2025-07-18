import 'package:flutter/material.dart';

class AppBarWidget extends StatefulWidget implements PreferredSizeWidget {
  const AppBarWidget({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AppBarWidget> createState() => _AppBarWidgetState();
}

class _AppBarWidgetState extends State<AppBarWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
      ), // fallback margin for small screens
      width: MediaQuery.of(context).size.width * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F6F6),
        border: Border(
          bottom: BorderSide(color: Color.fromARGB(255, 65, 55, 40), width: 2),
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFFF6F6F6),
        elevation: 0,
        actions: [
          IconButton(
            icon: Transform.flip(
              flipX: true,
              child: const Icon(Icons.notes_rounded),
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ],
        shape: null, // Remove shape since border is handled by Container
      ),
    );
  }
}
