import '../../../shared/api/api_response.dart';
import '../../../shared/api/authenticated_api.dart';
import 'board_api_paths.dart';

/// 좋아요 API 공통 응답에서 [liked], [likeCount] 추출. HTTP·success·data 불가 시 null.
({bool liked, int likeCount})? parseBoardLikeResponse(ApiResponse response) {
  if (response.statusCode != 200) return null;
  if (response.json['success'] != true) return null;
  final data = response.json['data'];
  if (data is! Map<String, dynamic>) return null;

  final liked = data['liked'] == true;
  final raw = data['likeCount'];
  int likeCount;
  if (raw is int) {
    likeCount = raw;
  } else if (raw is num) {
    likeCount = raw.toInt();
  } else {
    likeCount = int.tryParse('$raw') ?? 0;
  }
  return (liked: liked, likeCount: likeCount);
}

Future<ApiResponse> boardPostLike(String baseUrl, int boardId) {
  return postJsonWithAuth(baseUrl, BoardApiPaths.boardLikes(boardId), body: const {});
}

Future<ApiResponse> boardDeleteLike(String baseUrl, int boardId) {
  return deleteWithAuth(baseUrl, BoardApiPaths.boardLikes(boardId));
}
