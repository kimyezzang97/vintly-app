import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/report/data/report.dart';
import 'package:vintly_app/features/report/presentation/report_dialog.dart';

void main() {
  testWidgets('신고 다이얼로그에 사유와 500자 상세 입력을 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                showReportDialog(
                  context,
                  targetType: ReportTargetType.board,
                  targetId: 100,
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('신고하기'), findsOneWidget);
    expect(find.text('커뮤니티 게시글 신고 사유를 선택해 주세요.'), findsOneWidget);
    expect(find.text('상세 사유 (선택)'), findsOneWidget);
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).single.maxLength,
      500,
    );

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
  });
}
