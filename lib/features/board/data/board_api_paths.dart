/// 게시판 API 경로 (백엔드 스펙 그대로).
class BoardApiPaths {
  BoardApiPaths._();

  /// GET: keyword, page, size — POST multipart: title, content, images (max 10)
  static const String boards = '/api/v1/boards';

  /// POST multipart: title, content, images (max 10)
  static const String createBoard = boards;
}
