import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/features/auth/data/login_tokens.dart';
import 'package:vintly_app/shared/api/api_response.dart';

void main() {
  ApiResponse response(Map<String, List<String>> headers) => ApiResponse(
        statusCode: 200,
        rawBody: '',
        json: const <String, dynamic>{},
        headers: headers,
      );

  test('access 헤더와 refresh 쿠키를 파싱한다', () {
    final tokens = LoginTokens.fromResponse(
      response({
        'access': ['access-token'],
        'set-cookie': ['refresh=refresh-token; Path=/; HttpOnly'],
      }),
    );

    expect(tokens?.access, 'access-token');
    expect(tokens?.refresh, 'refresh-token');
  });

  test('Bearer authorization 헤더도 지원한다', () {
    final tokens = LoginTokens.fromResponse(
      response({
        'authorization': ['Bearer access-token'],
        'set-cookie': ['refresh=refresh-token; Path=/'],
      }),
    );

    expect(tokens?.access, 'access-token');
  });

  test('access 토큰이 없으면 실패한다', () {
    final tokens = LoginTokens.fromResponse(
      response({
        'set-cookie': ['refresh=refresh-token; Path=/'],
      }),
    );

    expect(tokens, isNull);
  });

  test('refresh 쿠키가 없거나 비어 있으면 실패한다', () {
    expect(
      LoginTokens.fromResponse(response({'access': ['access-token']})),
      isNull,
    );
    expect(
      LoginTokens.fromResponse(
        response({
          'access': ['access-token'],
          'set-cookie': ['refresh=; Path=/'],
        }),
      ),
      isNull,
    );
  });
}
