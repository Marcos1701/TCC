import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tcc_gen_app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  runApp(const GenApp());
}
