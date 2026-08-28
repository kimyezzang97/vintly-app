import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/board/data/board_list_response.dart';

void main() {
  group('parseBoardListBody 작성자 닉네임', () {
    test('authorNickname을 파싱한다', () {
      final result = parseBoardListBody({
        'data': {
          'content': [
            {
              'boardId': 1,
              'title': '빈티지 재킷 정보',
              'authorNickname': '빈티지러버',
              'viewCount': 3,
            },
          ],
          'totalElements': 1,
        },
      });

      expect(result, isNotNull);
      expect(result!.items.single.authorNickname, '빈티지러버');
    });

    test('authorNickname이 없으면 호환 닉네임 키를 사용한다', () {
      final result = parseBoardListBody({
        'data': [
          {'id': 2, 'title': '플리마켓 후기', 'nickname': '마켓탐험가'},
        ],
      });

      expect(result, isNotNull);
      expect(result!.items.single.authorNickname, '마켓탐험가');
    });

    test('작성자 필드가 없어도 빈 문자열로 안전하게 파싱한다', () {
      final result = parseBoardListBody({
        'data': [
          {'id': 3, 'title': '작성자 없는 응답'},
        ],
      });

      expect(result, isNotNull);
      expect(result!.items.single.authorNickname, isEmpty);
    });
  });
}
