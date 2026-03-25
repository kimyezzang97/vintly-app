// GET /api/v1/boards 응답 파싱 (success/data 래퍼 + Spring Page 스타일).

class BoardListRow {
  const BoardListRow({
    required this.id,
    required this.title,
    required this.viewCount,
    required this.dateLabel,
  });

  final int id;
  final String title;
  final int viewCount;
  final String dateLabel;
}

/// 서버 [json] 전체 맵에서 목록과 전체 건수를 뽑습니다. 실패 시 null.
({List<BoardListRow> items, int totalCount})? parseBoardListBody(
  Map<String, dynamic> json,
) {
  final dynamic data = json['data'];

  if (data is List) {
    final items = <BoardListRow>[];
    for (final raw in data) {
      if (raw is Map<String, dynamic>) {
        final row = _rowFromJson(raw);
        if (row != null) items.add(row);
      }
    }
    return (items: items, totalCount: items.length);
  }

  if (data is! Map<String, dynamic>) return null;

  final map = data;
  final List<dynamic>? rawList =
      map['content'] as List? ??
      map['items'] as List? ??
      map['boards'] as List? ??
      map['list'] as List?;

  if (rawList == null) return null;

  final items = <BoardListRow>[];
  for (final raw in rawList) {
    if (raw is Map<String, dynamic>) {
      final row = _rowFromJson(raw);
      if (row != null) items.add(row);
    }
  }

  final total = _readInt(map['totalElements']) ??
      _readInt(map['total']) ??
      _readInt(map['totalCount']) ??
      items.length;

  return (items: items, totalCount: total);
}

BoardListRow? _rowFromJson(Map<String, dynamic> m) {
  final id = _readInt(m['id'] ?? m['boardId']);
  if (id == null) return null;

  final title = (m['title'] ?? '').toString().trim();
  if (title.isEmpty) return null;

  final viewCount = _readInt(
        m['viewCount'] ??
            m['views'] ??
            m['hit'] ??
            m['readCount'] ??
            m['view_count'],
      ) ??
      0;

  final dateRaw =
      m['createdAt'] ?? m['createdDate'] ?? m['modifiedAt'] ?? m['date'];
  final dateLabel = _formatDateLabel(dateRaw);

  return BoardListRow(
    id: id,
    title: title,
    viewCount: viewCount,
    dateLabel: dateLabel,
  );
}

int? _readInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

String _formatDateLabel(dynamic raw) {
  if (raw == null) return '';
  final s = raw.toString();
  final dt = DateTime.tryParse(s);
  if (dt != null) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
  if (s.length >= 10) {
    return s.substring(0, 10).replaceAll('-', '.');
  }
  return s;
}
