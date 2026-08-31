import 'package:flutter_test/flutter_test.dart';
import 'package:vintly_app/shared/api/api_logger.dart';

void main() {
  test('요청 인증 헤더를 대소문자와 관계없이 마스킹한다', () {
    final source = {
      'access': 'access-token',
      'Authorization': 'Bearer access-token',
      'COOKIE': 'refresh=refresh-token',
      'content-type': 'application/json',
    };

    final sanitized = ApiLogSanitizer.requestHeaders(source);

    expect(sanitized['access'], '***');
    expect(sanitized['Authorization'], '***');
    expect(sanitized['COOKIE'], '***');
    expect(sanitized['content-type'], 'application/json');
    expect(source['access'], 'access-token');
  });

  test('응답 토큰 및 Set-Cookie 헤더를 마스킹한다', () {
    final source = {
      'access': ['access-token'],
      'set-cookie': ['refresh=refresh-token; Path=/; HttpOnly'],
      'content-type': ['application/json'],
    };

    final sanitized = ApiLogSanitizer.responseHeaders(source);

    expect(sanitized['access'], ['***']);
    expect(sanitized['set-cookie'], ['***']);
    expect(sanitized['content-type'], ['application/json']);
    expect(source['set-cookie'], ['refresh=refresh-token; Path=/; HttpOnly']);
  });
}
