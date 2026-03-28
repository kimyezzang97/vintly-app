// GET /api/v1/boards/{id} 응답 data 필드와 1:1 대응.

import 'board_comment.dart';

/// 수정 시 [PATCH] raminImgIdList 로 넘길 때 사용. [imgId]가 없으면 유지 ID를 알 수 없음.
class BoardDetailImageRef {
  const BoardDetailImageRef({this.imgId, required this.path});

  final int? imgId;
  final String path;
}

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
    required this.imgIds,
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
  /// [imgList]와 같은 길이. 맵 항목에서 imgId 등으로 채움.
  final List<int?> imgIds;
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
      imgIds: imgIds,
      comments: comments ?? this.comments,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  List<BoardDetailImageRef> get imageRefs => [
        for (var i = 0; i < imgList.length; i++)
          BoardDetailImageRef(
            imgId: i < imgIds.length ? imgIds[i] : null,
            path: imgList[i],
          ),
      ];

  factory BoardDetail.fromJson(Map<String, dynamic> json) {
    final parsed = _imgListAndIdsFromJson(json['imgList']);
    return BoardDetail(
      boardId: _intFromJson(json['boardId'] ?? json['id']),
      memberId: _intFromJson(json['memberId']),
      authorNickname: _stringFromJson(json['authorNickname'] ?? json['nickname']),
      title: _stringFromJson(json['title']),
      content: _stringFromJson(json['content']),
      viewCount: _intFromJson(json['viewCount']),
      likeCount: _intFromJson(json['likeCount']),
      liked: json['liked'] == true,
      imgList: parsed.$1,
      imgIds: parsed.$2,
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

  static int? _intNullableFromJson(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// (경로 목록, 각 항목의 이미지 id — 없으면 null)
  static (List<String>, List<int?>) _imgListAndIdsFromJson(dynamic raw) {
    if (raw is! List) return (<String>[], <int?>[]);
    final paths = <String>[];
    final ids = <int?>[];
    for (final item in raw) {
      if (item is String) {
        final s = item.trim();
        if (s.isNotEmpty) {
          paths.add(s);
          ids.add(null);
        }
      } else if (item is Map<String, dynamic>) {
        final p =
            item['imgPath'] ?? item['url'] ?? item['path'] ?? item['imageUrl'];
        if (p != null) {
          final s = p.toString().trim();
          if (s.isNotEmpty) {
            paths.add(s);
            final id = _intNullableFromJson(
              item['imgId'] ?? item['imageId'] ?? item['fileId'] ?? item['id'],
            );
            ids.add(id);
          }
        }
      }
    }
    return (paths, ids);
  }
}
