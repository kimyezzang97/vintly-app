import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/shared/api/api_response.dart';
import 'package:vintly_app/shared/auth/token_reissue.dart';

void main() {
  ApiResponse response(Map<String, List<String>> headers) => ApiResponse(
        statusCode: 200,
        rawBody: '',
        json: const <String, dynamic>{},
        headers: headers,
      );

  test('재발급 응답의 access 토큰을 읽는다', () {
    expect(
      accessTokenFromResponse(
        response({
          'access': ['new-access-token'],
        }),
      ),
      'new-access-token',
    );
  });

  test('재발급 응답의 access 토큰이 없거나 비어 있으면 실패한다', () {
    expect(accessTokenFromResponse(response(const {})), isNull);
    expect(
      accessTokenFromResponse(
        response({
          'access': ['  '],
        }),
      ),
      isNull,
    );
  });
}
