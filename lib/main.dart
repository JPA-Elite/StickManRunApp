import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/app/stickman_run_app.dart';
import 'game/settings/daily_mission.dart';
import 'game/settings/daily_streak.dart';
import 'game/settings/score_history.dart';
import 'game/settings/settings_controller.dart';
import 'game/settings/shop.dart';
import 'game/settings/skill_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Full-screen immersive: hide the status/navigation bars so system UI
  // never overlaps the game or swallows taps on the top buttons.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SettingsController.instance.load();
  await ScoreHistoryController.instance.load();
  await SkillController.instance.load();
  await ShopController.instance.load();
  await DailyStreakController.instance.load();
  await DailyMissionController.instance.load();
  runApp(const StickmanRunApp());
}
