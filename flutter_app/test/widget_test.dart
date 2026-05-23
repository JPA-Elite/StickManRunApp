// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app/notebook_app.dart';

void main() {
  testWidgets('NotebookApp renders (smoke test)', (WidgetTester tester) async {
    await tester.pumpWidget(const NotebookApp());

    // While SharedPreferences is loading, the app shows a progress indicator.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
