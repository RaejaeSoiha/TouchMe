import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_me/core/theme/app_theme.dart';

void main() {
  testWidgets('theme renders application title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Text('TouchMe')),
      ),
    );
    expect(find.text('TouchMe'), findsOneWidget);
  });
}
