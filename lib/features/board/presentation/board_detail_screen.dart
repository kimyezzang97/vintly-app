// 게시글 상세 — GET /api/v1/boards/{id}

import 'package:flutter/material.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/board_api_paths.dart';
import '../data/board_comment.dart';
import '../data/board_comment_api.dart';
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

/// true면 수정 시각이 등록과 다름 — 같으면(또는 파싱상 동일 시각) 수정 행 미표시.
bool _boardShowUpdatedLine(String created, String updated) {
  if (updated.trim().isEmpty) return false;
  final c = DateTime.tryParse(created.trim());
  final u = DateTime.tryParse(updated.trim());
  if (c != null && u != null) {
    return c.toUtc().millisecondsSinceEpoch != u.toUtc().millisecondsSinceEpoch;
  }
  return updated.trim() != created.trim();
}

String _formatBoardCommentDate(String iso) {
  if (iso.isEmpty) return '';
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
  final ScrollController _bodyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _bodyScrollController.dispose();
    super.dispose();
  }

  /// 댓글 입력창이 보이도록 본문 스크롤을 맨 아래로 내립니다.
  void _scrollToCommentInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_bodyScrollController.hasClients) return;
      final pos = _bodyScrollController.position;
      _bodyScrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// 상세 API 한 번 호출. 401/403이면 로그인으로 보내고 `(null, null)` 반환.
  /// `(detail, null)` 성공, `(null, 메시지)` 실패.
  Future<(BoardDetail?, String?)> _fetchBoardDetail() async {
    try {
      final baseUrl = AppConfig.instance.backend.baseUrl;
      final response = await getJsonWithAuth(
        baseUrl,
        BoardApiPaths.boardDetail(widget.boardId),
      );

      if (!mounted) return (null, null);

      final apiCode = response.code;
      if (response.statusCode == 401 ||
          apiCode == 401 ||
          response.statusCode == 403 ||
          apiCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return (null, null);
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return (null, null);
      }

      final success = response.json['success'] == true;
      final businessOk =
          apiCode == null || apiCode == 0 || apiCode == 200;
      if (!success || !businessOk || response.statusCode != 200) {
        return (
          null,
          response.msg ?? '게시글을 불러오지 못했습니다.',
        );
      }

      final data = response.json['data'];
      if (data is! Map<String, dynamic>) {
        return (null, '응답 형식이 올바르지 않습니다.');
      }

      try {
        final detail = BoardDetail.fromJson(data);
        return (detail, null);
      } catch (_) {
        return (null, '게시글 정보를 해석하지 못했습니다.');
      }
    } catch (e) {
      return (null, '네트워크 오류: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final result = await _fetchBoardDetail();
    if (!mounted) return;

    final detail = result.$1;
    final err = result.$2;
    if (detail == null && err == null) return;

    setState(() {
      _loading = false;
      _detail = detail;
      _errorMessage = detail == null ? err : null;
    });
  }

  Future<void> _refreshBoardDetailSilently() async {
    final result = await _fetchBoardDetail();
    if (!mounted) return;
    final detail = result.$1;
    if (detail == null) return;
    setState(() => _detail = detail);
  }

  Future<bool> _postBoardComment(String text, int parentCommentId) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    try {
      final response = await boardPostComment(
        baseUrl,
        widget.boardId,
        parentCommentId: parentCommentId,
        comment: text,
      );
      if (!mounted) return false;
      final apiCode = response.code;
      if (response.statusCode == 401 ||
          apiCode == 401 ||
          response.statusCode == 403 ||
          apiCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return false;
      }
      if (!boardCommentMutationOk(response)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.msg ?? '댓글 등록에 실패했습니다.')),
        );
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 등록되었습니다.')),
      );
      await _refreshBoardDetailSilently();
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

  Future<bool> _putBoardComment(int commentId, String text) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    try {
      final response = await boardPutComment(
        baseUrl,
        widget.boardId,
        commentId: commentId,
        comment: text,
      );
      if (!mounted) return false;
      final apiCode = response.code;
      if (response.statusCode == 401 ||
          apiCode == 401 ||
          response.statusCode == 403 ||
          apiCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return false;
      }
      if (!boardCommentMutationOk(response)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.msg ?? '댓글 수정에 실패했습니다.')),
        );
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 수정되었습니다.')),
      );
      await _refreshBoardDetailSilently();
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

  Future<bool> _deleteBoardComment(int commentId) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    try {
      final response = await boardDeleteComment(
        baseUrl,
        widget.boardId,
        commentId: commentId,
      );
      if (!mounted) return false;
      final apiCode = response.code;
      if (response.statusCode == 401 ||
          apiCode == 401 ||
          response.statusCode == 403 ||
          apiCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return false;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return false;
      }
      if (!boardCommentMutationOk(response)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.msg ?? '댓글 삭제에 실패했습니다.')),
        );
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 삭제되었습니다.')),
      );
      await _refreshBoardDetailSilently();
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

  Future<String?> _showEditBoardCommentDialog(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: controller,
          minLines: 1,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '댓글 내용',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.of(ctx).pop(t.isEmpty ? null : t);
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  Future<bool> _confirmDeleteBoardComment() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    return ok == true;
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
                        controller: _bodyScrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: _DetailBody(
                          detail: _detail!,
                          baseUrl: baseUrl,
                          likeBusy: _likeBusy,
                          onLikeTap: _toggleLike,
                          onScrollToCommentInput: _scrollToCommentInput,
                          onPostComment: _postBoardComment,
                          onEditComment: (c) async {
                            final text =
                                await _showEditBoardCommentDialog(c.content);
                            if (text == null || !mounted) return false;
                            return _putBoardComment(c.commentId, text);
                          },
                          onDeleteComment: (c) async {
                            final ok = await _confirmDeleteBoardComment();
                            if (!ok || !mounted) return false;
                            return _deleteBoardComment(c.commentId);
                          },
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
    required this.onScrollToCommentInput,
    required this.onPostComment,
    required this.onEditComment,
    required this.onDeleteComment,
  });

  final BoardDetail detail;
  final String baseUrl;
  final bool likeBusy;
  final VoidCallback onLikeTap;
  final VoidCallback onScrollToCommentInput;
  final Future<bool> Function(String comment, int parentCommentId) onPostComment;
  final Future<bool> Function(BoardComment c) onEditComment;
  final Future<bool> Function(BoardComment c) onDeleteComment;

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
        if (_boardShowUpdatedLine(detail.createdAt, detail.updatedAt))
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
        const SizedBox(height: 28),
        Divider(
          height: 1,
          thickness: 1,
          color: cs.outline.withValues(alpha: 0.18),
        ),
        const SizedBox(height: 16),
        _BoardCommentSection(
          comments: detail.comments,
          onScrollToCommentInput: onScrollToCommentInput,
          onPostComment: onPostComment,
          onEditComment: onEditComment,
          onDeleteComment: onDeleteComment,
        ),
      ],
    );
  }
}

class _BoardCommentSection extends StatefulWidget {
  const _BoardCommentSection({
    required this.comments,
    required this.onScrollToCommentInput,
    required this.onPostComment,
    required this.onEditComment,
    required this.onDeleteComment,
  });

  final List<BoardComment> comments;
  final VoidCallback onScrollToCommentInput;
  final Future<bool> Function(String comment, int parentCommentId) onPostComment;
  final Future<bool> Function(BoardComment c) onEditComment;
  final Future<bool> Function(BoardComment c) onDeleteComment;

  @override
  State<_BoardCommentSection> createState() => _BoardCommentSectionState();
}

class _BoardCommentSectionState extends State<_BoardCommentSection> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  BoardComment? _replyingTo;
  bool _submitting = false;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToInputAndFocus() {
    widget.onScrollToCommentInput();
    Future<void>.delayed(const Duration(milliseconds: 340), () {
      if (mounted) _inputFocusNode.requestFocus();
    });
  }

  /// 빈티지 댓글과 동일: 루트(parent==0) 아래에 직계 답글만 묶고, 각 단계는 작성 시각 오래된 순.
  List<({BoardComment c, bool isReply})> _flattenComments() {
    final all = widget.comments;
    final out = <({BoardComment c, bool isReply})>[];
    int cmpTime(BoardComment a, BoardComment b) =>
        a.createdAt.compareTo(b.createdAt);

    final tops = all.where((c) => c.parentCommentId == 0).toList()..sort(cmpTime);
    for (final p in tops) {
      out.add((c: p, isReply: false));
      final replies = all.where((c) => c.parentCommentId == p.commentId).toList()
        ..sort(cmpTime);
      for (final r in replies) {
        out.add((c: r, isReply: true));
      }
    }
    return out;
  }

  Future<void> _submit() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    final parentId = _replyingTo?.commentId ?? 0;
    final ok = await widget.onPostComment(text, parentId);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _inputController.clear();
      setState(() => _replyingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final currentMid = CurrentUserHolder.memberId;
    final flat = _flattenComments();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '댓글',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.comments.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        if (_replyingTo != null) ...[
          const SizedBox(height: 10),
          Material(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_replyingTo!.nickname.isEmpty ? '작성자' : _replyingTo!.nickname}님에게 답글',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: '답글 취소',
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _replyingTo = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (flat.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.12),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '아직 댓글이 없습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          )
        else
          ...flat.map((e) {
            final c = e.c;
            final isReply = e.isReply;
            final isMine =
                currentMid != null && c.memberId == currentMid;
            return _BoardCommentTile(
              comment: c,
              isReply: isReply,
              isMine: isMine,
              onTapForInput: _scrollToInputAndFocus,
              onReply: isReply
                  ? null
                  : () {
                      setState(() => _replyingTo = c);
                      _scrollToInputAndFocus();
                    },
              onEdit: isMine
                  ? () async {
                      await widget.onEditComment(c);
                    }
                  : null,
              onDelete: isMine
                  ? () async {
                      await widget.onDeleteComment(c);
                    }
                  : null,
            );
          }),
        const SizedBox(height: 16),
        Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    enabled: !_submitting,
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? '답글을 입력하세요'
                          : '댓글을 입력하세요',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                _submitting
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton.filledTonal(
                        onPressed: _submit,
                        tooltip: '등록',
                        icon: const Icon(Icons.send_rounded, size: 22),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BoardCommentTile extends StatelessWidget {
  const _BoardCommentTile({
    required this.comment,
    required this.isReply,
    required this.isMine,
    required this.onTapForInput,
    this.onReply,
    this.onEdit,
    this.onDelete,
  });

  final BoardComment comment;
  final bool isReply;
  final bool isMine;
  final VoidCallback onTapForInput;
  final VoidCallback? onReply;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nick =
        comment.nickname.isNotEmpty ? comment.nickname : '익명';
    final initial = nick.isNotEmpty ? nick[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply)
            Container(
              width: 3,
              margin: const EdgeInsets.only(right: 10, top: 6),
              constraints: const BoxConstraints(minHeight: 36),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapForInput,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              nick,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                                fontSize: isReply ? 12 : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatBoardCommentDate(comment.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: isReply ? 11 : null,
                            ),
                          ),
                          if (comment.edited) ...[
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
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
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
                                onTap: () => onEdit!(),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => onDelete!(),
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
                        comment.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: isReply ? 13 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
