// Basic smoke test for the SAPMS app.
//
// Verifies the app boots to its splash screen without throwing. The
// original template test referenced a non-existent `MyApp`/counter; this
// replaces it with a test against the real root widget, `SAPMSApp`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sapms_app/main.dart';

void main() {
  testWidgets('SAPMS app boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SAPMSApp());

    // The splash screen shows the app name.
    expect(find.text('SAPMS'), findsWidgets);

    // A loading spinner is present while auth state is checked.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
