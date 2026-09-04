import '../../../shared/api/api_response.dart';
import '../../../shared/api/authenticated_api.dart';
import 'report.dart';

const String reportsPath = '/api/v1/reports';

Future<ApiResponse> submitReport(
  String baseUrl, {
  required ReportTargetType targetType,
  required int targetId,
  required ReportReason reason,
  String? detail,
}) {
  final trimmedDetail = detail?.trim();
  return postJsonWithAuth(
    baseUrl,
    reportsPath,
    body: {
      'targetType': targetType.apiValue,
      'targetId': targetId,
      'reason': reason.apiValue,
      if (trimmedDetail != null && trimmedDetail.isNotEmpty)
        'detail': trimmedDetail,
    },
  );
}

Future<ApiResponse> fetchMyReports(String baseUrl) {
  return getJsonWithAuth(baseUrl, '$reportsPath/me');
}

List<ReportItem> parseReportItems(ApiResponse response) {
  final data = response.json['data'];
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => ReportItem.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
