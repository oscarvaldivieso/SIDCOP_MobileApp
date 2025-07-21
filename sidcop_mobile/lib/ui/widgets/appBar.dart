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
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF6F6F6),
      elevation: 0,
      flexibleSpace: SafeArea(
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.88,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFD9D9DD), width: 2),
              ),
              color: Colors.transparent,
            ),
            height: kToolbarHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
            ),
          ),
        ),
      ),
      toolbarHeight: kToolbarHeight,
    );
  }
}
