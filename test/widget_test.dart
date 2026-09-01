import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('로그인 화면의 기본 요소를 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('VINTLY'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('이용약관'), findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);
  });
}
