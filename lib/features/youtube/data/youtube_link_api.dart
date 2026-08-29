import '../../../shared/api/api_response.dart';
import '../../../shared/api/authenticated_api.dart';

const String youtubeLinksPath = '/api/v1/youtube-links';

Future<ApiResponse> getYoutubeLinks(
  String baseUrl, {
  required int page,
  int size = 10,
}) {
  return getJsonWithAuth(
    baseUrl,
    youtubeLinksPath,
    queryParameters: {'page': '$page', 'size': '$size'},
  );
}
