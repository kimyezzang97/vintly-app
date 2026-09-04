import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/block/data/block_api.dart';
import 'package:vintly_app/shared/api/api_response.dart';

void main() {
  test('차단 회원 목록 응답을 파싱한다', () {
    final response = ApiResponse(
      statusCode: 200,
      rawBody: '',
      headers: const {},
      json: const {
        'success': true,
        'code': 200,
        'data': [
          {
            'memberId': 2,
            'nickname': '차단한사람닉네임',
            'createdAt': '2026-09-03T12:00:00',
          },
        ],
      },
    );

    final members = parseBlockedMembers(response);

    expect(members, hasLength(1));
    expect(members.single.memberId, 2);
    expect(members.single.nickname, '차단한사람닉네임');
    expect(members.single.createdAt, '2026-09-03T12:00:00');
  });

  test('data가 배열이 아니면 빈 차단 목록을 반환한다', () {
    final response = ApiResponse(
      statusCode: 200,
      rawBody: '',
      headers: const {},
      json: const {'success': true, 'data': null},
    );

    expect(parseBlockedMembers(response), isEmpty);
  });
}
