import '../../../shared/api/api_response.dart';
import '../../../shared/api/authenticated_api.dart';
import 'blocked_member.dart';

const String blocksPath = '/api/v1/blocks';

Future<ApiResponse> blockMember(String baseUrl, int memberId) {
  return postJsonWithAuth(baseUrl, blocksPath, body: {'memberId': memberId});
}

Future<ApiResponse> unblockMember(String baseUrl, int memberId) {
  return deleteWithAuth(baseUrl, '$blocksPath/$memberId');
}

Future<ApiResponse> fetchBlockedMembers(String baseUrl) {
  return getJsonWithAuth(baseUrl, blocksPath);
}

List<BlockedMember> parseBlockedMembers(ApiResponse response) {
  final data = response.json['data'];
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => BlockedMember.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
