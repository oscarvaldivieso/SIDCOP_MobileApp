import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart' show AppBarWidget;
import 'package:sidcop_mobile/ui/widgets/drawer.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

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
        child: Center(
          child: Column(children: [Image.asset('assets/user.jpg')]),
        ),
      ),
    );
  }
}
