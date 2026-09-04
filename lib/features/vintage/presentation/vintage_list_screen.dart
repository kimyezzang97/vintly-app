// =============================================================================
// 빈티지 샵 지도 화면 (Vintage Map Screen)
// =============================================================================
//
// 로그인 후 보이는 메인 화면. GET /api/v1/vintages 로 목록을 받아 지도에 마커로 표시.
// 마커 탭 시 GET /api/v1/vintages/{id} 로 상세 조회 후 이미지·이름·주소·좋아요·댓글 표시 (lat/lon 미표시).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../../block/presentation/block_member_dialog.dart';
import '../../report/data/report.dart';
import '../../report/presentation/report_dialog.dart';
import '../data/vintage_shop.dart';
import '../data/vintage_shop_detail.dart';

class VintageListScreen extends StatefulWidget {
  const VintageListScreen({super.key});

  @override
  State<VintageListScreen> createState() => _VintageListScreenState();
}

class _VintageListScreenState extends State<VintageListScreen> {
  static const Color _ink = Color(0xFF241A17);
  static const Color _espresso = Color(0xFF3B241C);
  static const Color _caramel = Color(0xFFA96F3D);
  static const Color _cream = Color(0xFFF5F0E8);
  bool _loading = true;
  String? _errorMessage;
  bool _needReLogin = false;
  List<VintageShop> _shops = [];
  NaverMapController? _mapController;
  NOverlayImage? _shopMarkerIcon;
  static const NLatLng _defaultCenter = NLatLng(37.5665, 126.9780);
  static const double _defaultZoom = 12.0;
  static const String _vintagesPath = '/api/v1/vintages';

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    _mapController = null;
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
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        return;
      }

      if (response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
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
      await _renderShopsOnMap();
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

  Future<void> _renderShopsOnMap() async {
    final controller = _mapController;
    if (controller == null) return;

    await controller.clearOverlays(type: NOverlayType.marker);
    if (!mounted || controller != _mapController) return;

    final markerIcon = _shopMarkerIcon ??= await NOverlayImage.fromWidget(
      widget: const _VintageMapMarker(),
      size: const Size(40, 50),
      context: context,
    );
    if (!mounted || controller != _mapController) return;

    final markers = _shops.map((shop) {
      final marker = NMarker(
        id: 'vintage_${shop.vintageId}',
        position: NLatLng(shop.lat, shop.lon),
        icon: markerIcon,
        size: const Size(40, 50),
        caption: NOverlayCaption(
          text: shop.name,
          color: const Color(0xFF34383D),
          haloColor: Colors.white,
        ),
        captionOffset: 2,
      );
      marker.setOnTapListener((_) => _onMarkerTap(shop));
      return marker;
    }).toSet();
    if (markers.isNotEmpty) await controller.addOverlayAll(markers);

    if (_shops.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(_shops.first.lat, _shops.first.lon),
          zoom: 15,
        ),
      );
    } else if (_shops.length > 1) {
      final bounds = NLatLngBounds.from(
        _shops.map((shop) => NLatLng(shop.lat, shop.lon)),
      );
      await controller.updateCamera(
        NCameraUpdate.fitBounds(
          bounds,
          padding: const EdgeInsets.fromLTRB(48, 96, 48, 96),
        ),
      );
    }
  }

  /// 상세 API 호출: GET /api/v1/vintages/{id} (401 시 reissue 후 재시도).
  /// 401/403이면 needReLogin true로 반환 → 로그인 화면으로 이동.
  Future<({VintageShopDetail? detail, bool needReLogin})> _fetchShopDetail(
    int vintageId,
  ) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    final response = await getJsonWithAuth(
      baseUrl,
      '/api/v1/vintages/$vintageId',
    );

    final code = response.code ?? response.statusCode;
    if (response.statusCode == 401 ||
        code == 401 ||
        response.statusCode == 403) {
      return (detail: null, needReLogin: true);
    }
    if (response.statusCode != 200 || code != 200) {
      return (detail: null, needReLogin: false);
    }
    final data = response.json['data'];
    if (data is! Map<String, dynamic>) {
      return (detail: null, needReLogin: false);
    }
    try {
      return (detail: VintageShopDetail.fromJson(data), needReLogin: false);
    } catch (_) {
      return (detail: null, needReLogin: false);
    }
  }

  /// 마커 탭: 상세 API 호출 후 바텀시트로 상세 정보 표시 (lat/lon 제외)
  /// 로딩은 오버레이로만 표시해, 로딩 시트 닫힘 → 상세 시트 열림 이중 애니메이션을 피함.
  void _onMarkerTap(VintageShop shop) async {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ModalBarrier(color: Colors.transparent, dismissible: false),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
    overlay.insert(entry);
    var loadingRemoved = false;
    try {
      final result = await _fetchShopDetail(shop.vintageId);
      if (!mounted) return;

      if (result.needReLogin) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        return;
      }
      if (result.detail == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('상세 정보를 불러오지 못했습니다.')));
        return;
      }

      final access = await TokenStorage.getAccessToken();
      final imageHeaders = (access != null && access.isNotEmpty)
          ? <String, String>{'access': access}
          : null;
      if (!mounted) return;
      entry.remove();
      entry.dispose();
      loadingRemoved = true;
      _showDetailBottomSheet(result.detail!, imageRequestHeaders: imageHeaders);
    } finally {
      if (!loadingRemoved) {
        entry.remove();
        entry.dispose();
      }
    }
  }

  void _showDetailBottomSheet(
    VintageShopDetail detail, {
    Map<String, String>? imageRequestHeaders,
  }) {
    final theme = Theme.of(context);
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
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: StatefulBuilder(
            builder: (context, setStateSB) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              final isKeyboardVisible = bottomInset > 0.0;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8CEC6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 키보드가 올라오면 이미지와 주소를 숨겨 입력 영역 확보
                      if (!isKeyboardVisible)
                        Padding(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (detail.imgList.isNotEmpty) ...[
                                _VintageDetailImageCarousel(
                                  imgList: detail.imgList,
                                  baseUrl: AppConfig.instance.backend.baseUrl,
                                  imageRequestHeaders: imageRequestHeaders,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F2EC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFE8DDD3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          detail.name,
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: _espresso,
                                              ),
                                        ),
                                      ),
                                      if (likeLoading)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        Icon(
                                          liked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: liked
                                              ? Colors.red.shade600
                                              : const Color(0xFF8A817D),
                                          size: 20,
                                        ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$likeCount',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: _espresso,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              // 주소
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F2EC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE8DDD3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 20,
                                      color: _espresso,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        detail.address,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF5F5652),
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
                      _CommentSection(
                        detail: updatedDetail ?? detail,
                        replyingTo: replyingTo,
                        commentController: commentController,
                        commentFocusNode: commentFocusNode,
                        onReplyTap: (c) {
                          setStateSB(() => replyingTo = c);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            commentFocusNode.requestFocus();
                          });
                        },
                        onCancelReply: () =>
                            setStateSB(() => replyingTo = null),
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
                                ? () {
                                    setStateSB(() => replyingTo = c);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          commentFocusNode.requestFocus();
                                        });
                                  }
                                : null,
                            currentMemberId: CurrentUserHolder.memberId,
                            onEdit: () async {
                              final newContent = await _showEditCommentDialog(
                                context,
                                c.content,
                              );
                              if (newContent == null ||
                                  newContent.isEmpty ||
                                  !context.mounted) {
                                return;
                              }
                              final success = await _putComment(
                                vintageId: d.vintageId,
                                commentId: c.commentId,
                                comment: newContent,
                              );
                              if (!context.mounted) return;
                              if (success) {
                                final result = await _fetchShopDetail(
                                  d.vintageId,
                                );
                                if (context.mounted && result.detail != null) {
                                  setStateSB(
                                    () => updatedDetail = result.detail,
                                  );
                                }
                              }
                            },
                            onDelete: () async {
                              final confirm =
                                  await _showDeleteCommentConfirmDialog(
                                    context,
                                  );
                              if (confirm != true || !context.mounted) return;
                              final success = await _deleteComment(
                                vintageId: d.vintageId,
                                commentId: c.commentId,
                              );
                              if (!context.mounted) return;
                              if (success) {
                                final result = await _fetchShopDetail(
                                  d.vintageId,
                                );
                                if (context.mounted && result.detail != null) {
                                  setStateSB(
                                    () => updatedDetail = result.detail,
                                  );
                                }
                              }
                            },
                            onReport: () => showReportDialog(
                              context,
                              targetType: ReportTargetType.vintageComment,
                              targetId: c.commentId,
                            ),
                            onBlock: () async {
                              final blocked = await showBlockMemberDialog(
                                context,
                                memberId: c.memberId,
                                nickname: c.nickname,
                              );
                              if (!blocked || !context.mounted) return;
                              final result = await _fetchShopDetail(
                                d.vintageId,
                              );
                              if (context.mounted && result.detail != null) {
                                setStateSB(() => updatedDetail = result.detail);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
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

      if (response.statusCode == 401 ||
          code == 401 ||
          response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return null;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        return null;
      }

      final json = response.json;
      final success = json['success'] == true;
      final data = json['data'];
      if (!success || data is! Map<String, dynamic>) {
        final msg = response.msg ?? '좋아요 처리에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('좋아요 처리 중 오류: $e')));
      }
      return null;
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: Color(0xFFF2EAE2),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          size: 64,
          color: Color(0xFF8B6A59),
        ),
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
    Future<void> Function()? onReport,
    Future<void> Function()? onBlock,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final initial = c.nickname.isNotEmpty ? c.nickname[0].toUpperCase() : '?';
    final isMine = currentMemberId != null && c.memberId == currentMemberId;
    return Padding(
      padding: EdgeInsets.only(bottom: 14, left: isReply ? 40 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: const Color(0xFFF2E7DC),
            foregroundColor: const Color(0xFF4E342E),
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
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onReply,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply_outlined,
                                size: 16,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '답글',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (isMine && (onEdit != null || onDelete != null)) ...[
                      const SizedBox(width: 4),
                      if (onEdit != null)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onEdit(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: Text(
                              '수정',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.outline,
                              ),
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
                    if (!isMine && (onReport != null || onBlock != null)) ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: '댓글 관리',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.more_horiz, size: 19),
                        onSelected: (value) async {
                          if (value == 'report') await onReport?.call();
                          if (value == 'block') await onBlock?.call();
                        },
                        itemBuilder: (_) => [
                          if (onReport != null)
                            const PopupMenuItem(
                              value: 'report',
                              child: Text('댓글 신고'),
                            ),
                          if (onBlock != null)
                            const PopupMenuItem(
                              value: 'block',
                              child: Text('사용자 차단'),
                            ),
                        ],
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

  Future<String?> _showEditCommentDialog(
    BuildContext context,
    String initialContent,
  ) async {
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
      if (dt != null) {
        return '${dt.year}.${dt.month}.${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
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

      if (response.statusCode == 401 || code == 401) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        return false;
      }

      final success = response.json['success'] == true;
      if (!success) {
        final msg = response.msg ?? '댓글 등록에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글이 등록되었습니다.')));
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 등록 중 오류: $e')));
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
        body: {'commentId': commentId, 'comment': comment},
      );

      final code = response.code ?? response.statusCode;

      if (response.statusCode == 401 ||
          code == 401 ||
          response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        return false;
      }

      final success = response.json['success'] == true;
      if (!success) {
        final msg = response.msg ?? '댓글 수정에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글이 수정되었습니다.')));
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 수정 중 오류: $e')));
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

      if (response.statusCode == 401 ||
          code == 401 ||
          response.statusCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        return false;
      }

      final success = response.json['success'] == true;
      if (!success) {
        final msg = response.msg ?? '댓글 삭제에 실패했습니다.';
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        }
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('댓글이 삭제되었습니다.')));
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 삭제 중 오류: $e')));
      }
      return false;
    }
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
        backgroundColor: _cream,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 18,
                20,
                18,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
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
                          '빈티지 샵',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: _espresso,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2E7DC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${_shops.length}곳',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _espresso,
                        fontWeight: FontWeight.w800,
                      ),
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
                FilledButton(onPressed: _loadShops, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    if (_shops.isEmpty) {
      return const Center(child: Text('등록된 빈티지 샵이 없습니다.'));
    }

    return Stack(
      children: [
        NaverMap(
          options: const NaverMapViewOptions(
            initialCameraPosition: NCameraPosition(
              target: _defaultCenter,
              zoom: _defaultZoom,
            ),
          ),
          onMapReady: (controller) async {
            _mapController = controller;
            await _renderShopsOnMap();
          },
        ),
        Positioned(
          left: 16,
          top: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 18,
                  color: Color(0xFFD8B384),
                ),
                SizedBox(width: 8),
                Text(
                  '마커를 눌러 샵을 둘러보세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 20,
          child: Material(
            elevation: 5,
            borderRadius: BorderRadius.circular(14),
            color: _ink,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () =>
                      _mapController?.updateCamera(NCameraUpdate.zoomIn()),
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: '확대',
                ),
                const Divider(height: 1, color: Color(0xFF5B4A43)),
                IconButton(
                  onPressed: () =>
                      _mapController?.updateCamera(NCameraUpdate.zoomOut()),
                  icon: const Icon(Icons.remove, color: Colors.white),
                  tooltip: '축소',
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 20,
          child: Material(
            elevation: 5,
            color: _espresso,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _loading ? null : _loadShops,
              borderRadius: BorderRadius.circular(14),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VintageMapMarker extends StatelessWidget {
  const _VintageMapMarker();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 40,
      height: 50,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          CustomPaint(size: Size(40, 50), painter: _VintageMarkerPainter()),
          Positioned(
            top: 9,
            child: Icon(Icons.checkroom_rounded, size: 21, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _VintageMarkerPainter extends CustomPainter {
  const _VintageMarkerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalInset = 4.0;
    const topInset = 4.0;
    const bottomInset = 4.0;
    final radius = (size.width - horizontalInset * 2) / 2;
    final circleCenterY = topInset + radius;
    final tipY = size.height - bottomInset;

    final path = Path()
      ..moveTo(size.width / 2, tipY)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.76,
        horizontalInset,
        size.height * 0.58,
        horizontalInset,
        circleCenterY,
      )
      ..arcToPoint(
        Offset(size.width - horizontalInset, circleCenterY),
        radius: Radius.circular(radius),
        largeArc: true,
      )
      ..cubicTo(
        size.width - horizontalInset,
        size.height * 0.58,
        size.width * 0.58,
        size.height * 0.76,
        size.width / 2,
        tipY,
      )
      ..close();

    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = const Color(0xFF35424A));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE7ECEF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  final Widget Function(VintageComment c, {required bool isReply})
  commentTileBuilder;

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
            final replies =
                comments.where((c) => c.parentCommentId == t.commentId).toList()
                  ..sort(
                    (a, b) => a.createdAt.compareTo(b.createdAt),
                  ); // 오래된 순(위로)

            final children = <Widget>[commentTileBuilder(t, isReply: false)];

            // YouTube 스타일: 선택된 댓글 바로 아래에 답글 입력창 표시
            if (replyingTo != null && replyingTo!.commentId == t.commentId) {
              children.add(const SizedBox(height: 8));
              children.add(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        focusNode: commentFocusNode,
                        maxLines: 2,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: '답글을 입력하세요',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => onCommentSubmitted(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: onCommentSubmitted,
                      child: const Text('답글'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onCancelReply,
                      child: Text(
                        '취소',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              children.add(const SizedBox(height: 8));
            }

            children.addAll(
              replies.map((r) => commentTileBuilder(r, isReply: true)),
            );
            return children;
          }),
        const SizedBox(height: 16),
        if (replyingTo == null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: commentController,
                  focusNode: commentFocusNode,
                  maxLines: 2,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: '댓글을 입력하세요',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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

/// 상세 바텀시트용 이미지 캐러셀 — 여러 장 스와이프, 이름·좋아요 오버레이
class _VintageDetailImageCarousel extends StatefulWidget {
  const _VintageDetailImageCarousel({
    required this.imgList,
    required this.baseUrl,
    required this.imagePlaceholder,
    this.imageRequestHeaders,
    this.shopName,
    this.likeCount = 0,
    this.liked = false,
    this.likeLoading = false,
    this.onToggleLike,
  });

  final List<VintageImage> imgList;
  final String baseUrl;

  /// API 이미지가 access 헤더를 요구할 때 전달 (Image.network 에 그대로 사용)
  final Map<String, String>? imageRequestHeaders;
  final Widget imagePlaceholder;
  final String? shopName;
  final int likeCount;
  final bool liked;
  final bool likeLoading;
  final VoidCallback? onToggleLike;

  @override
  State<_VintageDetailImageCarousel> createState() =>
      _VintageDetailImageCarouselState();
}

class _VintageDetailImageCarouselState
    extends State<_VintageDetailImageCarousel> {
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
    final raw = img.imgPath.trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return raw;
    final base = widget.baseUrl.replaceAll(RegExp(r'/$'), '');
    return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
  }

  /// S3 등 외부 도메인에는 커스텀 헤더를 붙이면 403·디코딩 실패가 날 수 있음 → API와 같은 호스트일 때만 access 전달
  Map<String, String>? _headersForResolvedUrl(String url) {
    final extra = widget.imageRequestHeaders;
    if (extra == null || extra.isEmpty) return null;
    final imageUri = Uri.tryParse(url);
    final baseUri = Uri.tryParse(widget.baseUrl);
    if (imageUri == null || baseUri == null || !imageUri.hasScheme) return null;
    if (imageUri.host.isEmpty) return null;
    if (imageUri.host != baseUri.host) return null;
    if (imageUri.port != baseUri.port) return null;
    return extra;
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
                  final url = _imageUrl(img);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: url.isEmpty
                          ? widget.imagePlaceholder
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              headers: _headersForResolvedUrl(url),
                              errorBuilder: (_, _, _) =>
                                  widget.imagePlaceholder,
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
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
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
                  color: isActive
                      ? cs.primary
                      : cs.outline.withValues(alpha: 0.5),
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
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E1DA), width: 1),
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
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 22,
              color: liked ? const Color(0xFFC94848) : const Color(0xFF4E342E),
            ),
          const SizedBox(width: 6),
          Text(
            '$likeCount',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4E342E),
            ),
          ),
        ],
      ),
    );
  }
}
