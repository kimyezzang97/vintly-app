import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/youtube/data/youtube_link.dart';

void main() {
  test('유튜브 링크 페이지 응답을 파싱한다', () {
    final result = YoutubeLinkPage.fromResponse({
      'success': true,
      'data': {
        'content': [
          {
            'youtubeLinkId': 1,
            'url': 'https://www.youtube.com/watch?v=xxxxxxxxxxx',
            'title': '빈티지 자켓 코디',
            'description': null,
            'isAd': false,
            'createdAt': '2026-08-28T10:00:00',
            'updatedAt': '2026-08-28T10:00:00',
          },
        ],
        'page': 0,
        'size': 10,
        'totalElements': 1,
        'totalPages': 1,
        'first': true,
        'last': true,
      },
    });

    expect(result, isNotNull);
    expect(result!.content.single.youtubeLinkId, 1);
    expect(result.content.single.description, isNull);
    expect(result.last, isTrue);
  });

  test('필수 필드가 누락된 항목이 있으면 파싱에 실패한다', () {
    final result = YoutubeLinkPage.fromResponse({
      'data': {
        'content': [
          {'youtubeLinkId': 1, 'title': 'URL 없음'},
        ],
        'page': 0,
        'size': 10,
        'totalElements': 1,
        'totalPages': 1,
        'first': true,
        'last': true,
      },
    });

    expect(result, isNull);
  });

  test('지원하는 YouTube URL에서 썸네일 주소를 만든다', () {
    YoutubeLink link(String url) => YoutubeLink(
      youtubeLinkId: 1,
      url: url,
      title: '영상',
      description: null,
      isAd: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    expect(link('https://youtu.be/abc123').videoId, 'abc123');
    expect(
      link('https://www.youtube.com/watch?v=abc123').thumbnailUrl,
      'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
    );
    expect(link('https://youtube.com/shorts/short123').videoId, 'short123');
  });

  test('snake case is_ad 값 1을 광고로 파싱한다', () {
    final item = YoutubeLink.fromJson({
      'youtubeLinkId': 1,
      'url': 'https://youtu.be/abc123',
      'title': '광고 영상',
      'is_ad': 1,
      'createdAt': '2026-08-28T10:00:00',
      'updatedAt': '2026-08-28T10:00:00',
    });

    expect(item?.isAd, isTrue);
  });
}
