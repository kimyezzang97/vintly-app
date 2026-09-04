import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/block/presentation/block_member_dialog.dart';

void main() {
  testWidgets('사용자 차단 범위와 비공개 동작을 안내한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                showBlockMemberDialog(context, memberId: 2, nickname: '빈티지팬'),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('사용자 차단'), findsOneWidget);
    expect(find.text('빈티지팬님을 차단할까요?'), findsOneWidget);
    expect(find.textContaining('내 화면에서 보이지 않습니다'), findsOneWidget);
    expect(find.textContaining('차단 사실이 알려지지 않습니다'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });
}
