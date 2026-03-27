// 게시글 댓글 (board 상세 data.comments 항목).

class BoardComment {
  const BoardComment({
    required this.commentId,
    required this.memberId,
    required this.nickname,
    required this.content,
    required this.createdAt,
    required this.parentCommentId,
    this.edited = false,
  });

  final int commentId;
  final int memberId;
  final String nickname;
  final String content;
  final String createdAt;
  final int parentCommentId;
  final bool edited;

  factory BoardComment.fromJson(Map<String, dynamic> json) {
    return BoardComment(
      commentId: _intFromJson(json['commentId']),
      memberId: _intFromJson(json['memberId']),
      nickname: _firstNonEmptyNickname(json),
      content: _stringFromJson(
        json['comment'] ?? json['content'],
      ),
      createdAt: _stringFromJson(json['createdAt']),
      parentCommentId: _intFromJson(
        json['parentCommentId'] ?? json['parentId'],
      ),
      edited: _boolFromJson(json['edited']),
    );
  }

  static int _intFromJson(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _stringFromJson(dynamic v) => v?.toString() ?? '';

  /// `nickname`이 빈 문자열이어도 `authorNickname` 등 다음 키를 쓰도록 함.
  static String _firstNonEmptyNickname(Map<String, dynamic> json) {
    const keys = [
      'authorNickname',
      'nickname',
      'writer',
      'memberNickname',
      'userNickname',
    ];
    for (final k in keys) {
      final raw = json[k];
      if (raw == null) continue;
      final s = raw.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static bool _boolFromJson(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v.toInt() == 1;
    return false;
  }
}
