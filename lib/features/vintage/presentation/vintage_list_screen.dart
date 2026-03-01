// =============================================================================
// 빈티지 샵 지도 화면 (Vintage Map Screen)
// =============================================================================
//
// 로그인 후 보이는 메인 화면. GET /api/v1/vintages 로 목록을 받아 지도에 마커로 표시.
// 마커 탭 시 GET /api/v1/vintages/{id} 로 상세 조회 후 이미지·이름·주소·좋아요·댓글 표시 (lat/lon 미표시).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/vintage_shop.dart';
import '../data/vintage_shop_detail.dart';

class VintageListScreen extends StatefulWidget {
  const VintageListScreen({super.key});

  @override
  State<VintageListScreen> createState() => _VintageListScreenState();
}

class _VintageListScreenState extends State<VintageListScreen> {
  bool _loading = true;
  String? _errorMessage;
  bool _needReLogin = false;
  List<VintageShop> _shops = [];
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(37.5665, 126.9780);
  static const double _defaultZoom = 12.0;
  static const String _vintagesPath = '/api/v1/vintages';

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _needReLogin = false;
    });

    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = '로그인이 필요합니다.';
          _needReLogin = true;
        });
        return;
      }

      final baseUrl = AppConfig.instance.backend.baseUrl;
      // 401이면 reissue 후 한 번 재시도 (authenticated_api 공통 규칙)
      final response = await getJsonWithAuth(baseUrl, _vintagesPath);

      if (!mounted) return;
      final json = response.json;
      final code = response.code ?? response.statusCode;

      if (response.statusCode == 401 || code == 401) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return;
      }

      if (response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return;
      }

      final success = json['success'] == true;
      if (!success || code != 200) {
        setState(() {
          _loading = false;
          _errorMessage = response.msg ?? '목록을 불러오지 못했습니다.';
        });
        return;
      }

      final data = json['data'];
      List<VintageShop> shops = [];
      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            try {
              shops.add(VintageShop.fromJson(item));
            } catch (_) {}
          }
        }
      }

      setState(() {
        _loading = false;
        _shops = shops;
      });
    } catch (e, st) {
      debugPrint('[VintageList] _loadShops error: $e');
      debugPrint('[VintageList] stack: $st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '네트워크 오류가 발생했습니다. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clearAll();
    CurrentUserHolder.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  /// 상세 API 호출: GET /api/v1/vintages/{id} (401 시 reissue 후 재시도).
  /// 401/403이면 needReLogin true로 반환 → 로그인 화면으로 이동.
  Future<({VintageShopDetail? detail, bool needReLogin})> _fetchShopDetail(int vintageId) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    final response = await getJsonWithAuth(baseUrl, '/api/v1/vintages/$vintageId');

    final code = response.code ?? response.statusCode;
    if (response.statusCode == 401 || code == 401 || response.statusCode == 403) {
      return (detail: null, needReLogin: true);
    }
    if (response.statusCode != 200 || code != 200) {
      return (detail: null, needReLogin: false);
    }
    final data = response.json['data'];
    if (data is! Map<String, dynamic>) return (detail: null, needReLogin: false);
    try {
      return (detail: VintageShopDetail.fromJson(data), needReLogin: false);
    } catch (_) {
      return (detail: null, needReLogin: false);
    }
  }

  /// 마커 탭: 상세 API 호출 후 바텀시트로 상세 정보 표시 (lat/lon 제외)
  void _onMarkerTap(VintageShop shop) async {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('상세 정보를 불러오는 중...'),
            ],
          ),
        ),
      ),
    );

    final result = await _fetchShopDetail(shop.vintageId);
    if (!mounted) return;
    Navigator.of(context).pop(); // 로딩 시트 닫기

    if (result.needReLogin) {
      await TokenStorage.clearAll();
      CurrentUserHolder.clear();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      return;
    }
    if (result.detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상세 정보를 불러오지 못했습니다.')),
      );
      return;
    }

    _showDetailBottomSheet(result.detail!);
  }

  void _showDetailBottomSheet(VintageShopDetail detail) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    bool liked = detail.liked;
    int likeCount = detail.likeCount;
    bool likeLoading = false;
    VintageShopDetail? updatedDetail;
    VintageComment? replyingTo;
    final commentController = TextEditingController();
    final commentFocusNode = FocusNode();
    // 대댓글 포함 댓글이 3개 이상이면 시트를 꽉 채워서 열기
    final initialSheetSize = detail.comments.length >= 3 ? 0.95 : 0.75;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: initialSheetSize,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: StatefulBuilder(
            builder: (context, setStateSB) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 고정: 핸들 + 이미지 + 주소
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: cs.outline.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (detail.imgList.isNotEmpty) ...[
                        _VintageDetailImageCarousel(
                          imgList: detail.imgList,
                          baseUrl: AppConfig.instance.backend.baseUrl,
                          imagePlaceholder: _imagePlaceholder(),
                          shopName: detail.name,
                          likeCount: likeCount,
                          liked: liked,
                          likeLoading: likeLoading,
                          onToggleLike: () async {
                            if (likeLoading) return;
                            setStateSB(() => likeLoading = true);
                            final result = await _toggleLike(
                              vintageId: detail.vintageId,
                              currentLiked: liked,
                            );
                            if (!context.mounted) return;
                            setStateSB(() {
                              likeLoading = false;
                              if (result != null) {
                                liked = result.$1;
                                likeCount = result.$2;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        _imagePlaceholder(),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  detail.name,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              if (likeLoading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Icon(
                                  liked ? Icons.favorite : Icons.favorite_border,
                                  color: liked ? Colors.red.shade600 : cs.outline,
                                  size: 20,
                                ),
                              const SizedBox(width: 4),
                              Text(
                                '$likeCount',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // 주소
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined, size: 20, color: cs.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                detail.address,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                // 스크롤: 댓글만
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: _CommentSection(
                    detail: updatedDetail ?? detail,
                    replyingTo: replyingTo,
                    commentController: commentController,
                    commentFocusNode: commentFocusNode,
                    onReplyTap: (c) {
                      setStateSB(() => replyingTo = c);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        commentFocusNode.requestFocus();
                        if (scrollController.hasClients) {
                          scrollController.animateTo(
                            scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        }
                      });
                    },
                    onCancelReply: () => setStateSB(() => replyingTo = null),
                    onCommentSubmitted: () async {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;
                      final d = updatedDetail ?? detail;
                      final success = await _postComment(
                        vintageId: d.vintageId,
                        parentCommentId: replyingTo?.commentId ?? 0,
                        comment: text,
                      );
                      if (!context.mounted) return;
                      if (success) {
                        commentController.clear();
                        setStateSB(() => replyingTo = null);
                        final result = await _fetchShopDetail(d.vintageId);
                        if (context.mounted && result.detail != null) {
                          setStateSB(() => updatedDetail = result.detail);
                        }
                      }
                    },
                    commentTileBuilder: (c, {required bool isReply}) {
                      final d = updatedDetail ?? detail;
                      return _commentTile(
                        context,
                        c,
                        isReply: isReply,
                        onReply: c.parentCommentId == 0
                            ? () => setStateSB(() => replyingTo = c)
                            : null,
                        currentMemberId: CurrentUserHolder.memberId,
                        onEdit: () async {
                          final newContent = await _showEditCommentDialog(context, c.content);
                          if (newContent == null || newContent.isEmpty || !context.mounted) return;
                          final success = await _putComment(
                            vintageId: d.vintageId,
                            commentId: c.commentId,
                            comment: newContent,
                          );
                          if (!context.mounted) return;
                          if (success) {
                            final result = await _fetchShopDetail(d.vintageId);
                            if (context.mounted && result.detail != null) {
                              setStateSB(() => updatedDetail = result.detail);
                            }
                          }
                        },
                        onDelete: () async {
                          final confirm = await _showDeleteCommentConfirmDialog(context);
                          if (confirm != true || !context.mounted) return;
                          final success = await _deleteComment(
                            vintageId: d.vintageId,
                            commentId: c.commentId,
                          );
                          if (!context.mounted) return;
                          if (success) {
                            final result = await _fetchShopDetail(d.vintageId);
                            if (context.mounted && result.detail != null) {
                              setStateSB(() => updatedDetail = result.detail);
                            }
                          }
                        },
                      );
                    },
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        commentController.dispose();
        commentFocusNode.dispose();
      });
    });
  }

  /// 좋아요 토글 API 호출 (POST/DELETE) 후 새 liked, likeCount 반환
  Future<(bool, int)?> _toggleLike({
    required int vintageId,
    required bool currentLiked,
  }) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    final path = '/api/v1/vintages/$vintageId/likes';

    try {
      final response = currentLiked
          ? await deleteWithAuth(baseUrl, path)
          : await postJsonWithAuth(baseUrl, path, body: const {});

      final code = response.code ?? response.statusCode;

      if (response.statusCode == 401 || code == 401 || response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return null;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return null;
      }

      final json = response.json;
      final success = json['success'] == true;
      final data = json['data'];
      if (!success || data is! Map<String, dynamic>) {
        final msg = response.msg ?? '좋아요 처리에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
        return null;
      }

      final bool newLiked = data['liked'] == true;
      final dynamic likeCountRaw = data['likeCount'];
      int newLikeCount;
      if (likeCountRaw is int) {
        newLikeCount = likeCountRaw;
      } else if (likeCountRaw is num) {
        newLikeCount = likeCountRaw.toInt();
      } else {
        newLikeCount = int.tryParse('$likeCountRaw') ?? 0;
      }

      return (newLiked, newLikeCount);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('좋아요 처리 중 오류: $e')),
        );
      }
      return null;
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.store, size: 72, color: Colors.grey),
      ),
    );
  }

  Widget _commentTile(
    BuildContext context,
    VintageComment c, {
    bool isReply = false,
    VoidCallback? onReply,
    int? currentMemberId,
    Future<void> Function()? onEdit,
    Future<void> Function()? onDelete,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final initial = c.nickname.isNotEmpty ? c.nickname[0].toUpperCase() : '?';
    final isMine = currentMemberId != null && c.memberId == currentMemberId;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 14,
        left: isReply ? 40 : 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text(
              initial,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: isReply ? 12 : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.nickname,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        fontSize: isReply ? 12 : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(c.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: isReply ? 11 : null,
                      ),
                    ),
                    if (c.edited) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(수정됨)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: isReply ? 11 : null,
                        ),
                      ),
                    ],
                    if (onReply != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onReply,
                        child: Text(
                          '답글',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                    if (isMine && (onEdit != null || onDelete != null)) ...[
                      const SizedBox(width: 4),
                      if (onEdit != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => onEdit(),
                          child: Text(
                            '수정',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.outline,
                            ),
                          ),
                        ),
                      if (onDelete != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => onDelete(),
                          child: Text(
                            '삭제',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.error,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  c.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: isReply ? 13 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showEditCommentDialog(BuildContext context, String initialContent) async {
    final controller = TextEditingController(text: initialContent);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('댓글 수정'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: '댓글 내용',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(text.isEmpty ? null : text);
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  Future<bool> _showDeleteCommentConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('댓글 삭제'),
          content: const Text('이 댓글을 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.tryParse(iso);
      if (dt != null) return '${dt.year}.${dt.month}.${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
    return iso;
  }

  /// 댓글 작성 API: POST /api/v1/vintages/{vintageId}/comments
  Future<bool> _postComment({
    required int vintageId,
    required int parentCommentId,
    required String comment,
  }) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    final path = '/api/v1/vintages/$vintageId/comments';

    try {
      final response = await postJsonWithAuth(
        baseUrl,
        path,
        body: {
          'vintageId': vintageId,
          'parentCommentId': parentCommentId,
          'comment': comment,
        },
      );

      final code = response.code ?? response.statusCode;

      if (response.statusCode == 401 || code == 401 || response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return false;
      }

      final success = response.json['success'] == true;
      if (!success) {
        final msg = response.msg ?? '댓글 등록에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 등록되었습니다.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 등록 중 오류: $e')),
        );
      }
      return false;
    }
  }

  /// 댓글 수정 API: PUT /api/v1/vintages/{vintageId}/comments/{commentId}
  Future<bool> _putComment({
    required int vintageId,
    required int commentId,
    required String comment,
  }) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    final path = '/api/v1/vintages/$vintageId/comments/$commentId';

    try {
      final response = await putJsonWithAuth(
        baseUrl,
        path,
        body: {
          'commentId': commentId,
          'comment': comment,
        },
      );

      final code = response.code ?? response.statusCode;

      if (response.statusCode == 401 || code == 401 || response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return false;
      }

      final success = response.json['success'] == true;
      if (!success) {
        final msg = response.msg ?? '댓글 수정에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 수정되었습니다.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 수정 중 오류: $e')),
        );
      }
      return false;
    }
  }

  /// 댓글 삭제 API: DELETE /api/v1/vintages/{vintageId}/comments/{commentId}
  Future<bool> _deleteComment({
    required int vintageId,
    required int commentId,
  }) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    final path = '/api/v1/vintages/$vintageId/comments/$commentId';

    try {
      final response = await deleteWithAuth(baseUrl, path);

      final code = response.code ?? response.statusCode;

      if (response.statusCode == 401 || code == 401 || response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return false;
      }

      final success = response.json['success'] == true;
      if (!success) {
        final msg = response.msg ?? '댓글 삭제에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 삭제되었습니다.')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 삭제 중 오류: $e')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vintage Shops'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _logout,
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('목록을 불러오는 중...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (_needReLogin)
                FilledButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await TokenStorage.clearAll();
                    CurrentUserHolder.clear();
                    if (!mounted) return;
                    navigator.pushNamedAndRemoveUntil(
                      AppRoutes.login,
                      (route) => false,
                    );
                  },
                  child: const Text('다시 로그인'),
                )
              else
                FilledButton(
                  onPressed: _loadShops,
                  child: const Text('다시 시도'),
                ),
            ],
          ),
        ),
      );
    }

    if (_shops.isEmpty) {
      return const Center(child: Text('등록된 빈티지 샵이 없습니다.'));
    }

    const double minZoom = 3.0;
    const double maxZoom = 18.0;

    final markers = _shops.map((shop) {
      return Marker(
        point: LatLng(shop.lat, shop.lon),
        width: 48,
        height: 48,
        child: GestureDetector(
          onTap: () => _onMarkerTap(shop),
          child: const _VintageShopMarkerIcon(),
        ),
      );
    }).toList();

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              minZoom: minZoom,
              maxZoom: maxZoom,
              onMapReady: () {
                if (_shops.isEmpty) return;
                final points = _shops.map((s) => LatLng(s.lat, s.lon)).toList();
                _mapController.fitCamera(
                  CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(points),
                    padding: const EdgeInsets.all(48),
                  ),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.vintly.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 24,
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    final camera = _mapController.camera;
                    final next = (camera.zoom + 1).clamp(minZoom, maxZoom);
                    _mapController.move(camera.center, next);
                  },
                  icon: const Icon(Icons.add),
                  tooltip: '확대',
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                IconButton(
                  onPressed: () {
                    final camera = _mapController.camera;
                    final next = (camera.zoom - 1).clamp(minZoom, maxZoom);
                    _mapController.move(camera.center, next);
                  },
                  icon: const Icon(Icons.remove),
                  tooltip: '축소',
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
            child: IconButton(
              onPressed: _loading ? null : _loadShops,
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
            ),
          ),
        ),
      ],
    );
  }
}

/// 댓글 제목 + 트리(일반/대댓글) + 입력 필드
class _CommentSection extends StatelessWidget {
  const _CommentSection({
    required this.detail,
    required this.replyingTo,
    required this.commentController,
    this.commentFocusNode,
    required this.onReplyTap,
    required this.onCancelReply,
    required this.onCommentSubmitted,
    required this.commentTileBuilder,
  });

  final VintageShopDetail detail;
  final VintageComment? replyingTo;
  final TextEditingController commentController;
  final FocusNode? commentFocusNode;
  final void Function(VintageComment c) onReplyTap;
  final VoidCallback onCancelReply;
  final VoidCallback onCommentSubmitted;
  final Widget Function(VintageComment c, {required bool isReply}) commentTileBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final comments = detail.comments;
    final topLevel = comments.where((c) => c.parentCommentId == 0).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // 오래된 순(위로)

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 20, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              '댓글 (${comments.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (topLevel.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '아직 댓글이 없습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          )
        else
          ...topLevel.expand((t) {
            final replies = comments.where((c) => c.parentCommentId == t.commentId).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // 오래된 순(위로)
            return [
              commentTileBuilder(t, isReply: false),
              ...replies.map((r) => commentTileBuilder(r, isReply: true)),
            ];
          }),
        const SizedBox(height: 16),
        if (replyingTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  '답글: @${replyingTo!.nickname}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onCancelReply,
                  child: Text('취소', style: theme.textTheme.labelMedium?.copyWith(color: cs.outline)),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                focusNode: commentFocusNode,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: replyingTo != null ? '답글을 입력하세요' : '댓글을 입력하세요',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => onCommentSubmitted(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onCommentSubmitted,
              child: const Text('등록'),
            ),
          ],
        ),
      ],
    );
  }
}

class _VintageShopMarkerIcon extends StatelessWidget {
  const _VintageShopMarkerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.brown.shade400, Colors.amber.shade100, 0.2)!,
            Colors.brown.shade500,
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade900.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: const Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.store_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

/// 상세 바텀시트용 이미지 캐러셀 — 여러 장 스와이프, 이름·좋아요 오버레이
class _VintageDetailImageCarousel extends StatefulWidget {
  const _VintageDetailImageCarousel({
    required this.imgList,
    required this.baseUrl,
    required this.imagePlaceholder,
    this.shopName,
    this.likeCount = 0,
    this.liked = false,
    this.likeLoading = false,
    this.onToggleLike,
  });

  final List<VintageImage> imgList;
  final String baseUrl;
  final Widget imagePlaceholder;
  final String? shopName;
  final int likeCount;
  final bool liked;
  final bool likeLoading;
  final VoidCallback? onToggleLike;

  @override
  State<_VintageDetailImageCarousel> createState() => _VintageDetailImageCarouselState();
}

class _VintageDetailImageCarouselState extends State<_VintageDetailImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.hasClients
        ? (_pageController.page ?? 0).round()
        : 0;
    if (page != _currentPage && mounted) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  String _imageUrl(VintageImage img) {
    if (img.imgPath.startsWith('http')) return img.imgPath;
    final base = widget.baseUrl.replaceAll(RegExp(r'/$'), '');
    return img.imgPath.startsWith('/') ? '$base${img.imgPath}' : '$base/${img.imgPath}';
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.imgList;
    if (list.isEmpty) return widget.imagePlaceholder;

    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 320,
              child: PageView.builder(
                controller: _pageController,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final img = list[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _imageUrl(img),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => widget.imagePlaceholder,
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.shopName != null)
              Positioned(
                left: 16,
                right: 100,
                bottom: 16,
                child: Text(
                  widget.shopName!,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 8, offset: const Offset(0, 1)),
                      Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: widget.likeLoading ? null : widget.onToggleLike,
                child: _LikePillOverlay(
                  likeCount: widget.likeCount,
                  liked: widget.liked,
                  loading: widget.likeLoading,
                ),
              ),
            ),
          ],
        ),
        if (list.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(list.length, (index) {
              final isActive = index == _currentPage;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 12 : 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? cs.primary : cs.outline.withValues(alpha: 0.5),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// 사진 위 오버레이: 투명 흰색 타원 + 하트(3D) + 숫자, 로딩 시 인디케이터
class _LikePillOverlay extends StatelessWidget {
  const _LikePillOverlay({
    required this.likeCount,
    required this.liked,
    this.loading = false,
  });

  final int likeCount;
  final bool liked;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            _Heart3D(liked: liked),
          const SizedBox(width: 6),
          Text(
            '$likeCount',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(0, 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 하트 아이콘 — 살짝 3D 느낌 (그림자)
class _Heart3D extends StatelessWidget {
  const _Heart3D({required this.liked});

  final bool liked;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.15),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Icon(
        liked ? Icons.favorite : Icons.favorite_border,
        size: 22,
        color: liked ? Colors.red.shade400 : Colors.white,
      ),
    );
  }
}
