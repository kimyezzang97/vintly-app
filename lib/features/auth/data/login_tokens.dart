import '../../../shared/api/api_response.dart';

class LoginTokens {
  const LoginTokens({required this.access, required this.refresh});

  final String access;
  final String refresh;

  static LoginTokens? fromResponse(ApiResponse response) {
    final access = _firstNonEmpty(response.header('access')) ??
        _authorizationToken(response.header('authorization'));
    final refresh = _cookieValue(response.header('set-cookie'), 'refresh');

    if (access == null || refresh == null) return null;
    return LoginTokens(access: access, refresh: refresh);
  }
}

String? _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String? _authorizationToken(List<String> values) {
  final value = _firstNonEmpty(values);
  if (value == null) return null;
  if (value.toLowerCase().startsWith('bearer ')) {
    final token = value.substring(7).trim();
    return token.isEmpty ? null : token;
  }
  return value;
}

String? _cookieValue(List<String> cookies, String name) {
  for (final cookie in cookies) {
    final firstPart = cookie.split(';').first.trim();
    final separator = firstPart.indexOf('=');
    if (separator < 0) continue;
    if (firstPart.substring(0, separator).trim() != name) continue;

    final value = firstPart.substring(separator + 1).trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}
