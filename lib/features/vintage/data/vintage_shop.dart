// =============================================================================
// 빈티지 샵 모델 (Vintage Shop Model)
// =============================================================================
//
// API 응답의 data[] 한 항목과 1:1로 대응합니다.
// fromJson으로 JSON 맵을 VintageShop 객체로 변환할 때 사용합니다.
// =============================================================================

/// 빈티지 샵 한 개의 정보
class VintageShop {
  const VintageShop({
    required this.vintageId,
    required this.name,
    required this.state,
    required this.district,
    required this.detailAddr,
    required this.lat,
    required this.lon,
    this.thumbnailPath,
  });

  final int vintageId;
  final String name;
  final String state;
  final String district;
  final String detailAddr;
  final double lat;
  final double lon;
  /// 썸네일 이미지 URL. 없을 수 있음
  final String? thumbnailPath;

  /// API 응답의 data[] 한 항목(Map)을 VintageShop으로 변환합니다.
  /// 필드가 없거나 타입이 다르면 기본값을 쓰거나 예외가 날 수 있습니다.
  factory VintageShop.fromJson(Map<String, dynamic> json) {
    return VintageShop(
      vintageId: _intFromJson(json['vintageId']),
      name: _stringFromJson(json['name']),
      state: _stringFromJson(json['state']),
      district: _stringFromJson(json['district']),
      detailAddr: _stringFromJson(json['detailAddr']),
      lat: _doubleFromJson(json['lat']),
      lon: _doubleFromJson(json['lon']),
      thumbnailPath: json['thumbnailPath']?.toString(),
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

  /// 주소 한 줄 (state district detailAddr)
  String get address => '$state $district $detailAddr'.trim();
}
