// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_user_info.dart';
import 'package:skaletek_kyc_flutter/src/ui/layout/content.dart';
import 'package:skaletek_kyc_flutter/src/models/kyc_api_models.dart';

import 'package:skaletek_kyc_flutter/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('KYCContent shows dynamic name', (WidgetTester tester) async {
    // Create a user with a specific name
    final userInfo = KYCUserInfo(
      firstName: 'John',
      lastName: 'Doe',
      documentType: 'PASSPORT',
      issuingCountry: 'USA',
    );

    // Build the KYCContent widget with proper layout
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: KYCContent(
                  step: KYCStep.document,
                  userInfo: userInfo,
                  child: Container(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Verify that the greeting shows the correct name
    expect(find.text('Hey John!'), findsOneWidget);
  });

  testWidgets('KYCContent shows fallback when no user info', (
    WidgetTester tester,
  ) async {
    // Build the KYCContent widget without user info
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: KYCContent(step: KYCStep.document, child: Container()),
              ),
            ],
          ),
        ),
      ),
    );

    // Verify that the greeting shows the fallback text
    expect(find.text('Hey there!'), findsOneWidget);
  });
}
