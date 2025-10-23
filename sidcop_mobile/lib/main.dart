import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ocultar barras del sistema
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky, // O immersive
  );

  await initializeDateFormatting('es_ES', null);
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}
