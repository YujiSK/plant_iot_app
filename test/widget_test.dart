import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_iot_app/main.dart';

void main() {
  testWidgets('shows missing config message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MissingConfigPage()));

    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('SUPABASE_ANON_KEY'), findsOneWidget);
  });
}
