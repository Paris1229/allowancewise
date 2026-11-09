import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AllowanceWise branding images load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Image.asset('assets/AllowanceWise_app_icon.png', width: 64),
            Image.asset('assets/AllowanceWise_logo.png', width: 64),
            Image.asset('assets/AllowanceWise_logo_full.png', width: 128),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
