import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/youtube_link.dart';
import '../data/youtube_link_api.dart';

class YoutubeRecommendationScreen extends StatefulWidget {
  const YoutubeRecommendationScreen({super.key});

  @override
  State<YoutubeRecommendationScreen> createState() =>
      _YoutubeRecommendationScreenState();
}

class _YoutubeRecommendationScreenState
    extends State<YoutubeRecommendationScreen> {
  static const _espresso = Color(0xFF3B241C);
  static const _caramel = Color(0xFFA96F3D);
  static const _background = Color(0xFFF4F3F1);
  static const _pageSize = 10;

  final ScrollController _scrollController = ScrollController();
  List<YoutubeLink> _items = const [];
  int _currentPage = 0;
  int _totalPages = 0;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage(0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 300 &&
        !_loading &&
        _currentPage + 1 < _totalPages) {
      _loadPage(_currentPage + 1, append: true);
    }
  }

  Future<void> _loadPage(int page, {bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (!append) _errorMessage = null;
    });
    try {
      final response = await getYoutubeLinks(
        AppConfig.instance.backend.baseUrl,
        page: page,
        size: _pageSize,
      );
      if (!mounted) return;
      final code = response.code ?? response.statusCode;
      if (response.statusCode == 401 || code == 401) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        return;
      }
      if (response.statusCode != 200 ||
          code != 200 ||
          response.json['success'] != true) {
        _handleLoadFailure(
          response.msg ?? '추천 영상을 불러오지 못했습니다.',
          append: append,
        );
        return;
      }
      final parsed = YoutubeLinkPage.fromResponse(response.json);
      if (parsed == null) {
        _handleLoadFailure('추천 영상 응답 형식을 확인해 주세요.', append: append);
        return;
      }
      setState(() {
        _items = append ? [..._items, ...parsed.content] : parsed.content;
        _currentPage = parsed.page;
        _totalPages = parsed.totalPages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _handleLoadFailure('네트워크 연결을 확인하고 다시 시도해 주세요.', append: append);
    }
  }

  void _handleLoadFailure(String message, {required bool append}) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!append) _errorMessage = message;
    });
    if (append) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: '재시도',
            onPressed: () => _loadPage(_currentPage + 1, append: true),
          ),
        ),
      );
    }
  }

  Future<void> _openVideo(YoutubeLink item) async {
    final confirmed = await _confirmOpenVideo();
    if (!confirmed || !mounted) return;

    final uri = Uri.tryParse(item.url);
    final opened =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('영상 링크를 열 수 없습니다.')));
    }
  }

  Future<bool> _confirmOpenVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE8E1DA)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6ECE8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 28,
                    color: Color(0xFFC43D32),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'YouTube 열기',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF241A17),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'YouTube에서 영상을 여시겠어요?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF8A817D),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8A817D),
                          side: const BorderSide(color: Color(0xFFD8CEC6)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF35424A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('열기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 18,
                20,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VINTLY',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: _caramel,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '빈티지 YouTube',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: _espresso,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _caramel));
    }
    if (_errorMessage case final message?) {
      return _MessageState(
        icon: Icons.wifi_off_rounded,
        message: message,
        actionLabel: '다시 시도',
        onAction: () => _loadPage(_currentPage),
      );
    }
    if (_items.isEmpty) {
      return _MessageState(
        icon: Icons.smart_display_outlined,
        message: '아직 등록된 추천 영상이 없습니다.',
        actionLabel: '새로고침',
        onAction: () => _loadPage(0),
      );
    }
    return RefreshIndicator(
      color: _caramel,
      onRefresh: () => _loadPage(0),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _items.length + (_loading ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: CircularProgressIndicator(
                  color: _caramel,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          final item = _items[index];
          return _YoutubeLinkCard(item: item, onTap: () => _openVideo(item));
        },
      ),
    );
  }
}

class _YoutubeLinkCard extends StatelessWidget {
  const _YoutubeLinkCard({required this.item, required this.onTap});

  final YoutubeLink item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.createdAt;
    final dateLabel =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8E3DF)),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                height: 82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _YoutubeThumbnail(url: item.thumbnailUrl),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 38,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                    if (item.isAd)
                      const Positioned(right: 6, bottom: 6, child: _AdBadge()),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF241A17),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          dateLabel,
                          style: const TextStyle(
                            color: Color(0xFF9A918C),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          '영상 보기',
                          style: TextStyle(
                            color: Color(0xFF4E342E),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.open_in_new_rounded, size: 15),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YoutubeThumbnail extends StatelessWidget {
  const _YoutubeThumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFDED8D4),
      alignment: Alignment.center,
      child: const Icon(
        Icons.smart_display_outlined,
        size: 48,
        color: Color(0xFF8A817D),
      ),
    );
    if (url == null) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFEEEAE7),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }
}

class _AdBadge extends StatelessWidget {
  const _AdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Color(0xD9000000),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'AD',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: const Color(0xFF8A817D)),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
