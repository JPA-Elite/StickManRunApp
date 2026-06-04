import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/game/app/stickman_run_app.dart';

void main() {
  testWidgets('StickmanRunApp renders (smoke test)', (WidgetTester tester) async {
    await tester.pumpWidget(const StickmanRunApp());

    expect(find.text('STICKMAN RUN'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}
