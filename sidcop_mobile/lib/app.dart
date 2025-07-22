import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiUrl = dotenv.env['API_URL'] ?? 'api no definida';
    final apiKey = dotenv.env['API_KEY'] ?? 'api key no definida';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SIDCOP',
      theme: ThemeData(primarySwatch: Colors.indigo),
      // home: UserInfoScreen(), // Widget correcto
      home: const OnboardingScreen(),
    );
  }
}
