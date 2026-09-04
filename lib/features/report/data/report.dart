enum ReportTargetType {
  board('BOARD', '커뮤니티 게시글'),
  boardComment('BOARD_COMMENT', '게시글 댓글'),
  vintageComment('VINTAGE_COMMENT', '매장 댓글');

  const ReportTargetType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ReportTargetType? fromApiValue(String? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

enum ReportReason {
  obscene('OBSCENE', '음란물'),
  abuse('ABUSE', '욕설·비방'),
  spam('SPAM', '광고·스팸'),
  flood('FLOOD', '도배'),
  etc('ETC', '기타');

  const ReportReason(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ReportReason? fromApiValue(String? value) {
    for (final reason in values) {
      if (reason.apiValue == value) return reason;
    }
    return null;
  }
}

class ReportItem {
  const ReportItem({
    required this.reportId,
    required this.targetTypeValue,
    required this.targetId,
    required this.reasonValue,
    required this.status,
    required this.createdAt,
    this.detail,
  });

  final int reportId;
  final String targetTypeValue;
  final int targetId;
  final String reasonValue;
  final String? detail;
  final String status;
  final String createdAt;

  ReportTargetType? get targetType =>
      ReportTargetType.fromApiValue(targetTypeValue);
  ReportReason? get reason => ReportReason.fromApiValue(reasonValue);

  String get targetLabel => targetType?.label ?? '알 수 없는 대상';
  String get reasonLabel => reason?.label ?? '알 수 없는 사유';

  String get statusLabel => switch (status) {
    'PENDING' => '접수',
    'ACCEPTED' => '처리 완료',
    'REJECTED' => '기각',
    _ => '확인 중',
  };

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    final detailText = json['detail']?.toString().trim();
    return ReportItem(
      reportId: _intFromJson(json['reportId']),
      targetTypeValue: json['targetType']?.toString() ?? '',
      targetId: _intFromJson(json['targetId']),
      reasonValue: json['reason']?.toString() ?? '',
      detail: detailText == null || detailText.isEmpty ? null : detailText,
      status: json['status']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
