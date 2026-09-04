import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/report/data/report.dart';
import 'package:vintly_app/features/report/data/report_api.dart';
import 'package:vintly_app/shared/api/api_response.dart';

void main() {
  test('신고 목록 응답을 파싱한다', () {
    final response = ApiResponse(
      statusCode: 200,
      rawBody: '',
      headers: const {},
      json: const {
        'success': true,
        'code': 200,
        'data': [
          {
            'reportId': 10,
            'targetType': 'BOARD_COMMENT',
            'targetId': 100,
            'reason': 'ABUSE',
            'detail': '욕설이 포함되어 있습니다.',
            'status': 'PENDING',
            'createdAt': '2026-09-03T12:00:00',
          },
        ],
      },
    );

    final items = parseReportItems(response);

    expect(items, hasLength(1));
    expect(items.single.reportId, 10);
    expect(items.single.targetType, ReportTargetType.boardComment);
    expect(items.single.targetLabel, '게시글 댓글');
    expect(items.single.reason, ReportReason.abuse);
    expect(items.single.reasonLabel, '욕설·비방');
    expect(items.single.statusLabel, '접수');
  });

  test('서버에 새 enum 값이 와도 안전한 표시 문구를 사용한다', () {
    final item = ReportItem.fromJson(const {
      'reportId': 1,
      'targetType': 'NEW_TARGET',
      'targetId': 2,
      'reason': 'NEW_REASON',
      'status': 'NEW_STATUS',
      'createdAt': '',
    });

    expect(item.targetType, isNull);
    expect(item.reason, isNull);
    expect(item.targetLabel, '알 수 없는 대상');
    expect(item.reasonLabel, '알 수 없는 사유');
    expect(item.statusLabel, '확인 중');
  });

  test('data가 배열이 아니면 빈 목록을 반환한다', () {
    final response = ApiResponse(
      statusCode: 200,
      rawBody: '',
      headers: const {},
      json: const {'success': true, 'data': null},
    );

    expect(parseReportItems(response), isEmpty);
  });
}
