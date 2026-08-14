import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/game/app/stickman_run_app.dart';

void main() {
  testWidgets('StickmanRunApp renders (smoke test)', (WidgetTester tester) async {
    await tester.pumpWidget(const StickmanRunApp());

    // Home screen shows the two-line brand title and the big play button.
    expect(find.text('STICKMAN\nRUN'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
