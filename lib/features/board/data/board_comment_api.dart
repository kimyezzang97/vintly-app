import '../../../shared/api/api_response.dart';
import '../../../shared/api/authenticated_api.dart';
import 'board_api_paths.dart';

bool boardCommentMutationOk(ApiResponse response) {
  if (response.statusCode != 200) return false;
  return response.json['success'] == true;
}

Future<ApiResponse> boardPostComment(
  String baseUrl,
  int boardId, {
  required int parentCommentId,
  required String comment,
}) {
  return postJsonWithAuth(
    baseUrl,
    BoardApiPaths.boardComments(boardId),
    body: {
      'parentId': parentCommentId,
      'comment': comment,
    },
  );
}

Future<ApiResponse> boardPutComment(
  String baseUrl,
  int boardId, {
  required int commentId,
  required String comment,
}) {
  return putJsonWithAuth(
    baseUrl,
    BoardApiPaths.boardComment(boardId, commentId),
    body: {
      'comment': comment,
    },
  );
}

Future<ApiResponse> boardDeleteComment(
  String baseUrl,
  int boardId, {
  required int commentId,
}) {
  return deleteWithAuth(
    baseUrl,
    BoardApiPaths.boardComment(boardId, commentId),
  );
}
