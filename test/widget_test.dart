// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:vintly_app/app/vintly_app.dart';

void main() {
  testWidgets('VintlyApp boots and shows login', (WidgetTester tester) async {
    await tester.pumpWidget(const VintlyApp());
    await tester.pumpAndSettle();

    expect(find.text('Vintly'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
  });
}
