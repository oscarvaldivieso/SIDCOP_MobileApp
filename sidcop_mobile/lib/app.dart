import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sidcop_mobile/ui/screens/products/products_list_screen.dart';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';
import 'ui/screens/splash_lottie_screen.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/screens/home_screen.dart';
import 'package:sidcop_mobile/services/NavigationService.dart';
import 'package:sidcop_mobile/services/ConnectivitySyncService.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setImmersiveMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reaplica el modo inmersivo cuando la app vuelve al primer plano
      Future.delayed(const Duration(milliseconds: 100), _setImmersiveMode);
    }
  }

  void _setImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiUrl = dotenv.env['API_URL'] ?? 'api no definida';
    final apiKey = dotenv.env['API_KEY'] ?? 'api key no definida';
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIDCOP',
      theme: ThemeData(primarySwatch: Colors.indigo),
      navigatorKey: NavigationService.navigatorKey,
      home: const SplashLottieScreen(),
    );
  }
}