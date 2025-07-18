import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/appBackground.dart';
import 'package:sidcop_mobile/ui/widgets/appBar.dart' show AppBarWidget;
import 'package:sidcop_mobile/ui/widgets/drawer.dart';

class RechargeList extends StatefulWidget {
  const RechargeList({super.key});

  @override
  State<RechargeList> createState() => _RechargeListState();
}

class _RechargeListState extends State<RechargeList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Color(0xFFF6F6F6),
      body: AppBackground(
        title: 'Recarga',
        icon: Icons.sync,
      ),
      // appBar: const AppBarWidget(),
      // drawer: const CustomDrawer(),
    );
  }
}
