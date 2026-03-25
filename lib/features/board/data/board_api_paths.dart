/// 게시판 API 경로 (백엔드 스펙 그대로).
class BoardApiPaths {
  BoardApiPaths._();

  /// POST multipart: title, content, images (max 10)
  static const String createBoard = '/api/v1/boards';
}
