// 게시글 상세 — GET /api/v1/boards/{id}

import 'package:flutter/material.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/board_api_paths.dart';
import '../data/board_detail.dart';
import '../data/board_like_api.dart';

String _formatBoardDetailDate(String iso) {
  if (iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso);
  if (dt != null) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return iso.length > 16 ? iso.substring(0, 16) : iso;
}

String _resolveBoardImageUrl(String baseUrl, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  final base = baseUrl.replaceAll(RegExp(r'/$'), '');
  return trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
}

Map<String, String>? _boardDetailImageHeaders(
  String baseUrl,
  String imageUrl,
  String? access,
) {
  if (access == null || access.isEmpty) return null;
  final imageUri = Uri.tryParse(imageUrl);
  final baseUri = Uri.tryParse(baseUrl);
  if (imageUri == null || baseUri == null || !imageUri.hasScheme) return null;
  if (imageUri.host.isEmpty) return null;
  if (imageUri.host != baseUri.host || imageUri.port != baseUri.port) {
    return null;
  }
  return {'access': access};
}

class BoardDetailScreen extends StatefulWidget {
  const BoardDetailScreen({super.key, required this.boardId});

  final int boardId;

  @override
  State<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends State<BoardDetailScreen> {
  bool _loading = true;
  String? _errorMessage;
  BoardDetail? _detail;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final baseUrl = AppConfig.instance.backend.baseUrl;
      final response = await getJsonWithAuth(
        baseUrl,
        BoardApiPaths.boardDetail(widget.boardId),
      );

      if (!mounted) return;

      final apiCode = response.code;
      if (response.statusCode == 401 ||
          apiCode == 401 ||
          response.statusCode == 403 ||
          apiCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return;
      }

      final success = response.json['success'] == true;
      final businessOk =
          apiCode == null || apiCode == 0 || apiCode == 200;
      if (!success || !businessOk || response.statusCode != 200) {
        setState(() {
          _loading = false;
          _errorMessage = response.msg ?? '게시글을 불러오지 못했습니다.';
          _detail = null;
        });
        return;
      }

      final data = response.json['data'];
      if (data is! Map<String, dynamic>) {
        setState(() {
          _loading = false;
          _errorMessage = '응답 형식이 올바르지 않습니다.';
          _detail = null;
        });
        return;
      }

      try {
        final detail = BoardDetail.fromJson(data);
        setState(() {
          _loading = false;
          _detail = detail;
          _errorMessage = null;
        });
        await _syncLikesQuiet();
      } catch (_) {
        setState(() {
          _loading = false;
          _errorMessage = '게시글 정보를 해석하지 못했습니다.';
          _detail = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '네트워크 오류: $e';
        _detail = null;
      });
    }
  }

  /// GET /boards/{id}/likes 로 표시용 좋아요 상태를 맞춥니다. 실패해도 상세 조회 값을 유지합니다.
  Future<void> _syncLikesQuiet() async {
    if (!mounted || _detail == null) return;
    final baseUrl = AppConfig.instance.backend.baseUrl;
    try {
      final response = await boardGetLikes(baseUrl, widget.boardId);
      if (!mounted) return;
      final syncCode = response.code;
      if (response.statusCode == 401 ||
          syncCode == 401 ||
          response.statusCode == 403 ||
          syncCode == 403) {
        return;
      }
      final parsed = parseBoardLikeResponse(response);
      if (parsed == null) return;
      setState(() {
        _detail = _detail!.copyWith(
          liked: parsed.liked,
          likeCount: parsed.likeCount,
        );
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_detail == null || _likeBusy) return;
    setState(() => _likeBusy = true);
    final baseUrl = AppConfig.instance.backend.baseUrl;
    final currentLiked = _detail!.liked;
    try {
      final response = currentLiked
          ? await boardDeleteLike(baseUrl, widget.boardId)
          : await boardPostLike(baseUrl, widget.boardId);

      if (!mounted) return;

      final likeApiCode = response.code;
      if (response.statusCode == 401 ||
          likeApiCode == 401 ||
          response.statusCode == 403 ||
          likeApiCode == 403) {
        setState(() => _likeBusy = false);
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return;
      }

      final parsed = parseBoardLikeResponse(response);
      if (parsed == null) {
        setState(() => _likeBusy = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.msg ?? '좋아요 처리에 실패했습니다.')),
          );
        }
        return;
      }

      setState(() {
        _likeBusy = false;
        _detail = _detail!.copyWith(
          liked: parsed.liked,
          likeCount: parsed.likeCount,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _likeBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 처리 중 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final baseUrl = AppConfig.instance.backend.baseUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              : _detail == null
                  ? const Center(child: Text('표시할 내용이 없습니다.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: _DetailBody(
                          detail: _detail!,
                          baseUrl: baseUrl,
                          likeBusy: _likeBusy,
                          onLikeTap: _toggleLike,
                        ),
                      ),
                    ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.detail,
    required this.baseUrl,
    required this.likeBusy,
    required this.onLikeTap,
  });

  final BoardDetail detail;
  final String baseUrl;
  final bool likeBusy;
  final VoidCallback onLikeTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          detail.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: _BoardDetailMediaArea(
            rawPaths: detail.imgList,
            baseUrl: baseUrl,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 18, color: cs.onSurfaceVariant),
            Text(
              detail.authorNickname.isEmpty ? '—' : detail.authorNickname,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            Text('·', style: TextStyle(color: cs.outline)),
            Icon(Icons.visibility_outlined,
                size: 18, color: cs.onSurfaceVariant),
            Text(
              '${detail.viewCount}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text('·', style: TextStyle(color: cs.outline)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: likeBusy ? null : onLikeTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (likeBusy)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      else
                        Icon(
                          detail.liked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 18,
                          color: detail.liked
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${detail.likeCount}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '등록 ${_formatBoardDetailDate(detail.createdAt)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        if (detail.updatedAt.isNotEmpty &&
            detail.updatedAt != detail.createdAt)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '수정 ${_formatBoardDetailDate(detail.updatedAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 12),
        SelectableText(
          detail.content,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
      ],
    );
  }
}

/// 인스타그램 피드처럼 정사각형 미디어 영역을 고정하고, 이미지가 없으면 플레이스홀더만 표시합니다.
class _BoardDetailMediaArea extends StatefulWidget {
  const _BoardDetailMediaArea({
    required this.rawPaths,
    required this.baseUrl,
  });

  final List<String> rawPaths;
  final String baseUrl;

  @override
  State<_BoardDetailMediaArea> createState() => _BoardDetailMediaAreaState();
}

class _BoardDetailMediaAreaState extends State<_BoardDetailMediaArea> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.rawPaths.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Center(
            child: Icon(
              Icons.image_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<String?>(
      future: TokenStorage.getAccessToken(),
      builder: (context, snapshot) {
        final access = snapshot.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.rawPaths.length,
                onPageChanged: (i) => setState(() => _pageIndex = i),
                itemBuilder: (context, index) {
                  final resolved = _resolveBoardImageUrl(
                    widget.baseUrl,
                    widget.rawPaths[index],
                  );
                  if (resolved.isEmpty) {
                    return ColoredBox(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final headers = _boardDetailImageHeaders(
                    widget.baseUrl,
                    resolved,
                    access,
                  );
                  return Image.network(
                    resolved,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    headers: headers,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return ColoredBox(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                        child: const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => ColoredBox(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (widget.rawPaths.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: IgnorePointer(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.rawPaths.length, (i) {
                        final active = i == _pageIndex;
                        return Container(
                          width: active ? 7 : 6,
                          height: active ? 7 : 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
