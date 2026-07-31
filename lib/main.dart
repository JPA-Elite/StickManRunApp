import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/app/stickman_run_app.dart';
import 'game/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SettingsController.instance.load();
  runApp(const StickmanRunApp());
}
