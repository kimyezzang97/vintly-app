class BlockedMember {
  const BlockedMember({
    required this.memberId,
    required this.nickname,
    required this.createdAt,
  });

  final int memberId;
  final String nickname;
  final String createdAt;

  factory BlockedMember.fromJson(Map<String, dynamic> json) {
    return BlockedMember(
      memberId: _intFromJson(json['memberId']),
      nickname: json['nickname']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
