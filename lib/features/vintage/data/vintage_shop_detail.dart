// =============================================================================
// 빈티지 샵 상세 모델 (Vintage Shop Detail)
// =============================================================================
//
// GET /api/v1/vintages/{id} 응답의 data와 1:1 대응합니다.
// imgList, comments 포함. lat/lon은 화면에 노출하지 않음.
// =============================================================================

/// 상세 API 이미지 한 건
class VintageImage {
  const VintageImage({
    required this.vintageImgId,
    required this.imgPath,
  });

  final int vintageImgId;
  final String imgPath;

  factory VintageImage.fromJson(Map<String, dynamic> json) {
    return VintageImage(
      vintageImgId: _intFromJson(json['vintageImgId']),
      imgPath: _stringFromJson(json['imgPath']),
    );
  }

  static int _intFromJson(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _stringFromJson(dynamic v) => v?.toString() ?? '';
}

/// 댓글 한 건 (대댓글은 parentCommentId > 0)
class VintageComment {
  const VintageComment({
    required this.commentId,
    required this.memberId,
    required this.nickname,
    required this.content,
    required this.createdAt,
    this.parentCommentId = 0,
    this.edited = false,
  });

  final int commentId;
  final int memberId;
  final String nickname;
  final String content;
  final String createdAt;
  /// 0이면 일반 댓글, 0보다 크면 해당 commentId에 대한 대댓글
  final int parentCommentId;
  /// true면 수정된 댓글 (UI에서 "수정됨" 표시)
  final bool edited;

  factory VintageComment.fromJson(Map<String, dynamic> json) {
    return VintageComment(
      commentId: _intFromJson(json['commentId']),
      memberId: _intFromJson(json['memberId']),
      nickname: _stringFromJson(json['nickname']),
      content: _stringFromJson(json['content']),
      createdAt: _stringFromJson(json['createdAt']),
      parentCommentId: _intFromJson(json['parentCommentId']),
      edited: _boolFromJson(json['edited']),
    );
  }

  static int _intFromJson(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _stringFromJson(dynamic v) => v?.toString() ?? '';

  static bool _boolFromJson(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    if (v is num) return v.toInt() == 1;
    return false;
  }
}

/// 빈티지 샵 상세 (GET /api/v1/vintages/{id} data)
class VintageShopDetail {
  const VintageShopDetail({
    required this.vintageId,
    required this.name,
    required this.state,
    required this.district,
    required this.detailAddr,
    required this.lat,
    required this.lon,
    required this.imgList,
    required this.likeCount,
    required this.liked,
    required this.comments,
  });

  final int vintageId;
  final String name;
  final String state;
  final String district;
  final String detailAddr;
  final double lat;
  final double lon;
  final List<VintageImage> imgList;
  final int likeCount;
  final bool liked;
  final List<VintageComment> comments;

  /// 주소 한 줄 (state district detailAddr). lat/lon은 화면에 안 보여줌.
  String get address => '$state $district $detailAddr'.trim();

  factory VintageShopDetail.fromJson(Map<String, dynamic> json) {
    final imgRaw = json['imgList'];
    List<VintageImage> imgs = [];
    if (imgRaw is List) {
      for (final item in imgRaw) {
        if (item is Map<String, dynamic>) {
          try {
            imgs.add(VintageImage.fromJson(item));
          } catch (_) {}
        }
      }
    }

    final commentsRaw = json['comments'];
    List<VintageComment> commentList = [];
    if (commentsRaw is List) {
      for (final item in commentsRaw) {
        if (item is Map<String, dynamic>) {
          try {
            commentList.add(VintageComment.fromJson(item));
          } catch (_) {}
        }
      }
    }

    return VintageShopDetail(
      vintageId: _intFromJson(json['vintageId']),
      name: _stringFromJson(json['name']),
      state: _stringFromJson(json['state']),
      district: _stringFromJson(json['district']),
      detailAddr: _stringFromJson(json['detailAddr']),
      lat: _doubleFromJson(json['lat']),
      lon: _doubleFromJson(json['lon']),
      imgList: imgs,
      likeCount: _intFromJson(json['likeCount']),
      liked: json['liked'] == true,
      comments: commentList,
    );
  }

  static int _intFromJson(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _doubleFromJson(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static String _stringFromJson(dynamic v) => v?.toString() ?? '';
}
