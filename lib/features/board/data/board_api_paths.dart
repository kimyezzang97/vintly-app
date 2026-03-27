/// 게시판 API 경로 (백엔드 스펙 그대로).
class BoardApiPaths {
  BoardApiPaths._();

  /// GET: keyword, page, size — POST multipart: title, content, images (max 10)
  static const String boards = '/api/v1/boards';

  /// POST multipart: title, content, images (max 10)
  static const String createBoard = boards;

  /// GET 상세
  static String boardDetail(int boardId) => '/api/v1/boards/$boardId';

  /// GET/POST/DELETE 좋아요 상태·등록·취소
  static String boardLikes(int boardId) => '/api/v1/boards/$boardId/likes';

  /// POST 댓글 등록
  static String boardComments(int boardId) =>
      '/api/v1/boards/$boardId/comments';

  /// PUT/DELETE 댓글
  static String boardComment(int boardId, int commentId) =>
      '/api/v1/boards/$boardId/comments/$commentId';
}
