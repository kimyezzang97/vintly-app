import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/auth/presentation/sign_up_screen.dart';

void main() {
  testWidgets('필수 동의 전에는 회원가입 버튼을 비활성화한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

    const agreement = '필수 항목에 모두 동의합니다.';
    final signUpButton = find.widgetWithText(FilledButton, '회원가입');

    expect(find.text(agreement), findsOneWidget);
    expect(find.text('만 14세 이상임을 확인합니다.'), findsOneWidget);
    expect(find.text('이용약관'), findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);
    expect(tester.widget<FilledButton>(signUpButton).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<FilledButton>(signUpButton).onPressed, isNotNull);
  });
}
