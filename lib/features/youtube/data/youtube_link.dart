class YoutubeLink {
  const YoutubeLink({
    required this.youtubeLinkId,
    required this.url,
    required this.title,
    required this.description,
    required this.isAd,
    required this.createdAt,
    required this.updatedAt,
  });

  final int youtubeLinkId;
  final String url;
  final String title;
  final String? description;
  final bool isAd;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? get videoId {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final host = uri.host.toLowerCase().replaceFirst('www.', '');
    if (host == 'youtu.be') {
      return uri.pathSegments.firstOrNull;
    }
    if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
      final queryId = uri.queryParameters['v']?.trim();
      if (queryId != null && queryId.isNotEmpty) return queryId;
      if (uri.pathSegments.length >= 2 &&
          const {'shorts', 'embed', 'live'}.contains(uri.pathSegments.first)) {
        return uri.pathSegments[1];
      }
    }
    return null;
  }

  String? get thumbnailUrl {
    final id = videoId;
    return id == null || id.isEmpty
        ? null
        : 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
  }

  static YoutubeLink? fromJson(Map<String, dynamic> json) {
    final id = _readInt(json['youtubeLinkId']);
    final url = json['url']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (id == null ||
        url.isEmpty ||
        title.isEmpty ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }

    final descriptionText = json['description']?.toString().trim();
    return YoutubeLink(
      youtubeLinkId: id,
      url: url,
      title: title,
      description: descriptionText == null || descriptionText.isEmpty
          ? null
          : descriptionText,
      isAd: _readBool(json['isAd'] ?? json['is_ad']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class YoutubeLinkPage {
  const YoutubeLinkPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  final List<YoutubeLink> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  static YoutubeLinkPage? fromResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map<String, dynamic>) return null;
    final rawContent = data['content'];
    final page = _readInt(data['page']);
    final size = _readInt(data['size']);
    final totalElements = _readInt(data['totalElements']);
    final totalPages = _readInt(data['totalPages']);
    if (rawContent is! List ||
        page == null ||
        size == null ||
        totalElements == null ||
        totalPages == null ||
        data['first'] is! bool ||
        data['last'] is! bool) {
      return null;
    }

    final content = <YoutubeLink>[];
    for (final raw in rawContent) {
      if (raw is! Map<String, dynamic>) return null;
      final item = YoutubeLink.fromJson(raw);
      if (item == null) return null;
      content.add(item);
    }

    return YoutubeLinkPage(
      content: content,
      page: page,
      size: size,
      totalElements: totalElements,
      totalPages: totalPages,
      first: data['first'] as bool,
      last: data['last'] as bool,
    );
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

bool _readBool(dynamic value) {
  return value == true || value == 1 || value?.toString() == '1';
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
