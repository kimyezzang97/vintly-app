// =============================================================================
// Board — GET /api/v1/boards (keyword, page, size) 목록·검색·페이지.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/board_api_paths.dart';
import '../data/board_list_response.dart';
import 'board_create_screen.dart';
import 'board_detail_screen.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  static const int _pageSize = 12;
  static const Color _ink = Color(0xFF241A17);
  static const Color _espresso = Color(0xFF3B241C);
  static const Color _caramel = Color(0xFFA96F3D);
  static const Color _background = Color(0xFFF4F3F1);

  final TextEditingController _searchController = TextEditingController();

  final List<_BoardListItem> _items = [];
  String _queryTrimmed = '';
  int _currentPage = 0;
  int _totalCount = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPage(0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalPages {
    if (_totalCount <= 0) return 0;
    return (_totalCount + _pageSize - 1) ~/ _pageSize;
  }

  Future<void> _loadPage(int page) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _queryTrimmed = _searchController.text.trim();
      _currentPage = page;
    });

    final result = await _fetchBoardData(page: page, query: _queryTrimmed);
    if (!mounted) return;

    var newPage = page;
    final totalPages = result.totalCount <= 0
        ? 0
        : (result.totalCount + _pageSize - 1) ~/ _pageSize;
    if (totalPages > 0 && newPage >= totalPages) {
      newPage = totalPages - 1;
      final adjusted = await _fetchBoardData(
        page: newPage,
        query: _queryTrimmed,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(adjusted.items);
        _totalCount = adjusted.totalCount;
        _currentPage = newPage;
        _loading = false;
      });
      return;
    }

    setState(() {
      _items
        ..clear()
        ..addAll(result.items);
      _totalCount = result.totalCount;
      _currentPage = newPage;
      _loading = false;
    });
  }

  Future<({List<_BoardListItem> items, int totalCount})> _fetchBoardData({
    required int page,
    required String query,
  }) async {
    try {
      final baseUrl = AppConfig.instance.backend.baseUrl;
      final qp = <String, String>{'page': '$page', 'size': '$_pageSize'};
      if (query.isNotEmpty) qp['keyword'] = query;

      final response = await getJsonWithAuth(
        baseUrl,
        BoardApiPaths.boards,
        queryParameters: qp,
      );

      final code = response.code ?? response.statusCode;
      if (response.statusCode == 401 ||
          code == 401 ||
          response.statusCode == 403 ||
          code == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (mounted) {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
        }
        return (items: <_BoardListItem>[], totalCount: 0);
      }

      final success = response.json['success'] == true;
      if (!success || code != 200 || response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.msg ?? '목록을 불러오지 못했습니다.')),
          );
        }
        return (items: <_BoardListItem>[], totalCount: 0);
      }

      final parsed = parseBoardListBody(response.json);
      if (parsed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('목록 응답 형식을 해석하지 못했습니다.')),
          );
        }
        return (items: <_BoardListItem>[], totalCount: 0);
      }

      final items = parsed.items
          .map(
            (r) => _BoardListItem(
              id: r.id,
              title: r.title,
              authorNickname: r.authorNickname,
              viewCount: r.viewCount,
              dateLabel: r.dateLabel,
            ),
          )
          .toList();

      return (items: items, totalCount: parsed.totalCount);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      }
      return (items: <_BoardListItem>[], totalCount: 0);
    }
  }

  void _onSearchSubmitted(String _) => _loadPage(0);

  Future<void> _onRefresh() => _loadPage(_currentPage);

  Future<void> _openBoardDetail(int boardId) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BoardDetailScreen(boardId: boardId),
      ),
    );
    if (deleted == true && mounted) _loadPage(_currentPage);
  }

  Future<void> _openCreateBoard() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const BoardCreateScreen()));
    if (created == true && mounted) await _loadPage(0);
  }

  /// 화면에 보일 페이지 번호 (0-based). 전체가 많으면 현재 주변만.
  List<int> _visiblePageIndices() {
    if (_totalPages <= 0) return [];
    const maxVisible = 5;
    if (_totalPages <= maxVisible) {
      return List<int>.generate(_totalPages, (i) => i);
    }
    var start = _currentPage - (maxVisible ~/ 2);
    if (start < 0) start = 0;
    if (start + maxVisible > _totalPages) start = _totalPages - maxVisible;
    return List<int>.generate(maxVisible, (i) => start + i);
  }

  Widget _buildPagination() {
    final pages = _visiblePageIndices();
    final canGoBack = _currentPage > 0;
    final canGoForward = _currentPage < _totalPages - 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFD8CEC6), width: 1)),
      ),
      child: _loading
          ? const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _caramel,
                  ),
                ),
              ),
            )
          : Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PagingMiniButton(
                      label: '‹',
                      tooltip: '이전',
                      onPressed: canGoBack
                          ? () => _loadPage(_currentPage - 1)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    ...pages.map((index) {
                      final selected = index == _currentPage;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _PagingPageButton(
                          pageLabel: '${index + 1}',
                          selected: selected,
                          onPressed: selected ? null : () => _loadPage(index),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    _PagingMiniButton(
                      label: '›',
                      tooltip: '다음',
                      onPressed: canGoForward
                          ? () => _loadPage(_currentPage + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
    );
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
                14,
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
                          '커뮤니티',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: _espresso,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openCreateBoard,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF35424A),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      '글쓰기',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: SearchBar(
                controller: _searchController,
                hintText: '제목이나 내용으로 검색',
                hintStyle: const WidgetStatePropertyAll(
                  TextStyle(color: Color(0xFF8A817D)),
                ),
                leading: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF5F5652),
                ),
                trailing: [
                  IconButton(
                    tooltip: '검색',
                    onPressed: _loading
                        ? null
                        : () => _onSearchSubmitted(_searchController.text),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
                onSubmitted: _loading ? null : _onSearchSubmitted,
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: const WidgetStatePropertyAll(Colors.white),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: Color(0xFFE8DDD3)),
                ),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _queryTrimmed.isEmpty ? '게시글' : '검색 결과',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$_totalCount개',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF8A817D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: _caramel,
                onRefresh: _onRefresh,
                child: _loading && _items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: _caramel),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                        itemCount: _items.isEmpty ? 1 : _items.length,
                        itemBuilder: (context, index) {
                          if (_items.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 72),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.forum_outlined,
                                    size: 42,
                                    color: Color(0xFFB6AAA2),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _queryTrimmed.isEmpty
                                        ? '아직 작성된 글이 없어요.'
                                        : '검색 결과가 없어요.',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: const Color(0xFF6F6560),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final item = _items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _BoardListTile(
                              item: item,
                              onTap: () => _openBoardDetail(item.id),
                            ),
                          );
                        },
                      ),
              ),
            ),
            if (_items.isNotEmpty) _buildPagination(),
          ],
        ),
      ),
    );
  }
}

class _PagingMiniButton extends StatelessWidget {
  const _PagingMiniButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFF35424A),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PagingPageButton extends StatelessWidget {
  const _PagingPageButton({
    required this.pageLabel,
    required this.selected,
    required this.onPressed,
  });

  final String pageLabel;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF2E7DC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          pageLabel,
          style: const TextStyle(
            color: Color(0xFF3B241C),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: const Color(0xFF6F6560),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(pageLabel),
    );
  }
}

class _BoardListItem {
  const _BoardListItem({
    required this.id,
    required this.title,
    required this.authorNickname,
    required this.viewCount,
    required this.dateLabel,
  });

  final int id;
  final String title;
  final String authorNickname;
  final int viewCount;
  final String dateLabel;
}

class _BoardListTile extends StatelessWidget {
  const _BoardListTile({required this.item, required this.onTap});

  final _BoardListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _BoardScreenState._ink,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.authorNickname.isEmpty
                                ? '작성자 정보 없음'
                                : item.authorNickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6F6560),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: TextStyle(color: Color(0xFFB6AAA2)),
                          ),
                        ),
                        const Icon(
                          Icons.visibility_outlined,
                          size: 15,
                          color: Color(0xFF8A817D),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item.viewCount}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF8A817D),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.dateLabel.isEmpty ? '—' : item.dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF8A817D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB6AAA2)),
            ],
          ),
        ),
      ),
    );
  }
}
