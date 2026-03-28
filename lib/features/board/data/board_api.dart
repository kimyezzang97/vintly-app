import '../../../shared/api/api_response.dart';
import '../../../shared/api/authenticated_api.dart';
import 'board_api_paths.dart';

/// PATCH /api/v1/boards/{id} — multipart: title, content, raminImgIdList(JSON 배열 문자열), imgList(신규 파일)
Future<ApiResponse> boardPatchUpdate(
  String baseUrl,
  int boardId, {
  required String title,
  required String content,
  required String raminImgIdListJson,
  required List<({String filename, List<int> bytes, String contentType})>
      newImageFiles,
}) {
  return patchMultipartWithAuth(
    baseUrl,
    BoardApiPaths.boardDetail(boardId),
    fields: {
      'title': title,
      'content': content,
      'raminImgIdList': raminImgIdListJson,
    },
    fileFieldName: 'imgList',
    files: newImageFiles,
  );
}

/// DELETE /api/v1/boards/{id}
Future<ApiResponse> boardDelete(String baseUrl, int boardId) {
  return deleteWithAuth(baseUrl, BoardApiPaths.boardDetail(boardId));
}

bool boardDeleteMutationOk(ApiResponse response) {
  final sc = response.statusCode;
  if (sc != 200 && sc != 204) return false;
  if (response.json.isEmpty) return true;
  return response.json['success'] == true;
}
