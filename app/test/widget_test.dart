// Basic smoke test: without --dart-define Supabase config, the app should
// show the "not configured" screen rather than crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:basirah_app/main.dart';

void main() {
  testWidgets('App launches and shows a screen without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const BasirahApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
