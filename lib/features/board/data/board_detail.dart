// GET /api/v1/boards/{id} 응답 data 필드와 1:1 대응.

import 'board_comment.dart';

class BoardDetail {
  const BoardDetail({
    required this.boardId,
    required this.memberId,
    required this.authorNickname,
    required this.title,
    required this.content,
    required this.viewCount,
    required this.likeCount,
    required this.liked,
    required this.imgList,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
  });

  final int boardId;
  final int memberId;
  final String authorNickname;
  final String title;
  final String content;
  final int viewCount;
  final int likeCount;
  final bool liked;
  /// API 원본 경로(상대/절대 URL). 화면에서 baseUrl과 합쳐 사용.
  final List<String> imgList;
  final List<BoardComment> comments;
  final String createdAt;
  final String updatedAt;

  BoardDetail copyWith({
    bool? liked,
    int? likeCount,
    List<BoardComment>? comments,
  }) {
    return BoardDetail(
      boardId: boardId,
      memberId: memberId,
      authorNickname: authorNickname,
      title: title,
      content: content,
      viewCount: viewCount,
      likeCount: likeCount ?? this.likeCount,
      liked: liked ?? this.liked,
      imgList: imgList,
      comments: comments ?? this.comments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory BoardDetail.fromJson(Map<String, dynamic> json) {
    return BoardDetail(
      boardId: _intFromJson(json['boardId'] ?? json['id']),
      memberId: _intFromJson(json['memberId']),
      authorNickname: _stringFromJson(json['authorNickname'] ?? json['nickname']),
      title: _stringFromJson(json['title']),
      content: _stringFromJson(json['content']),
      viewCount: _intFromJson(json['viewCount']),
      likeCount: _intFromJson(json['likeCount']),
      liked: json['liked'] == true,
      imgList: _imgListFromJson(json['imgList']),
      comments: _commentsFromJson(json['comments']),
      createdAt: _stringFromJson(json['createdAt']),
      updatedAt: _stringFromJson(json['updatedAt']),
    );
  }

  static List<BoardComment> _commentsFromJson(dynamic raw) {
    if (raw is! List) return [];
    final out = <BoardComment>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        try {
          out.add(BoardComment.fromJson(item));
        } catch (_) {}
      }
    }
    return out;
  }

  static int _intFromJson(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _stringFromJson(dynamic v) => v?.toString() ?? '';

  static List<String> _imgListFromJson(dynamic raw) {
    if (raw is! List) return [];
    final out = <String>[];
    for (final item in raw) {
      if (item is String) {
        if (item.trim().isNotEmpty) out.add(item);
      } else if (item is Map<String, dynamic>) {
        final p =
            item['imgPath'] ?? item['url'] ?? item['path'] ?? item['imageUrl'];
        if (p != null) {
          final s = p.toString().trim();
          if (s.isNotEmpty) out.add(s);
        }
      }
    }
    return out;
  }
}
