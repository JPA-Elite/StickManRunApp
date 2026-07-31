import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/app/stickman_run_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const StickmanRunApp());
}
