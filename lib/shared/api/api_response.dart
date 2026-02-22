class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.rawBody,
    required this.json,
    required this.headers,
  });

  final int statusCode;
  final String rawBody;
  final Map<String, dynamic> json;
  final Map<String, List<String>> headers;

  List<String> header(String name) {
    final key = name.toLowerCase();
    return headers[key] ?? const <String>[];
  }

  int? get code {
    final dynamic codeRaw = json['code'];
    if (codeRaw is int) return codeRaw;
    return int.tryParse('$codeRaw');
  }

  String? get msg {
    final dynamic m = json['msg'] ?? json['message'];
    return m?.toString();
  }
}

