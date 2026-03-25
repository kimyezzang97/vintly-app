// =============================================================================
// Board (UI 틀) — 검색 / 목록 / 페이지 이동. API 연동 전 더미 데이터.
// =============================================================================

import 'package:flutter/material.dart';

import 'board_create_screen.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  static const int _pageSize = 15;

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
      final adjusted = await _fetchBoardData(page: newPage, query: _queryTrimmed);
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

  /// API 자리: 로컬 더미로 필터·total·슬라이스.
  Future<({List<_BoardListItem> items, int totalCount})> _fetchBoardData({
    required int page,
    required String query,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final q = query.toLowerCase();
    final all = _dummySource()
        .where((e) => q.isEmpty || e.title.toLowerCase().contains(q) || e.summary.toLowerCase().contains(q))
        .toList();
    final total = all.length;
    final start = page * _pageSize;
    if (start >= total) {
      return (items: <_BoardListItem>[], totalCount: total);
    }
    final end = (start + _pageSize).clamp(0, total);
    return (items: all.sublist(start, end), totalCount: total);
  }

  List<_BoardListItem> _dummySource() {
    return List<_BoardListItem>.generate(52, (i) {
      return _BoardListItem(
        id: i + 1,
        title: '게시글 제목 ${i + 1} — 빈티지 후기 & 질문',
        summary: '내용 미리보기입니다. 실제 연동 시 본문 일부가 들어갑니다. (#${i + 1})',
        dateLabel: '${2025 - (i % 3)}.${(i % 12) + 1}.${(i % 27) + 1}',
      );
    });
  }

  void _onSearchSubmitted(String _) => _loadPage(0);

  Future<void> _onRefresh() => _loadPage(_currentPage);

  int get _listItemCount {
    if (_loading && _items.isEmpty) return 0;
    if (_items.isEmpty && !_loading) return 1;
    return _items.length;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pages = _visiblePageIndices();
    final canGoBack = !_loading && _currentPage > 0;
    final canGoForward = !_loading && _currentPage < _totalPages - 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Board'),
        actions: [
          IconButton(
            tooltip: '글 작성',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const BoardCreateScreen()),
              );
              if (created == true && mounted) _loadPage(0);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: '제목·내용 검색',
              leading: const Icon(Icons.search),
              trailing: [
                IconButton(
                  tooltip: '검색',
                  onPressed: _loading ? null : () => _onSearchSubmitted(_searchController.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
              onSubmitted: _loading ? null : _onSearchSubmitted,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _listItemCount,
                      itemBuilder: (context, index) {
                        if (_items.isEmpty && !_loading && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('검색 결과가 없습니다.')),
                          );
                        }
                        final item = _items[index];
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BoardListTile(item: item),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: cs.outline.withValues(alpha: 0.15),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
          ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  height: 3,
                  thickness: 2,
                  color: cs.outline.withValues(alpha: 0.22),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_totalCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '전체 $_totalCount건',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (_loading)
                          const SizedBox(
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else if (_totalPages <= 0)
                          const SizedBox(
                            height: 40,
                            child: Center(child: Text('—')),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _PagingMiniButton(
                                      label: '<<',
                                      tooltip: '첫 페이지',
                                      onPressed: canGoBack ? () => _loadPage(0) : null,
                                      scheme: cs,
                                      compact: true,
                                    ),
                                    _PagingMiniButton(
                                      label: '<',
                                      tooltip: '이전',
                                      onPressed: canGoBack ? () => _loadPage(_currentPage - 1) : null,
                                      scheme: cs,
                                      compact: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                ...pages.map((index) {
                                  final n = index + 1;
                                  final selected = index == _currentPage;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: _PagingPageButton(
                                      pageLabel: '$n',
                                      selected: selected,
                                      onPressed: !selected ? () => _loadPage(index) : null,
                                      scheme: cs,
                                    ),
                                  );
                                }),
                                const SizedBox(width: 4),
                                _PagingMiniButton(
                                  label: '>',
                                  tooltip: '다음',
                                  onPressed: canGoForward ? () => _loadPage(_currentPage + 1) : null,
                                  scheme: cs,
                                ),
                                _PagingMiniButton(
                                  label: '>>',
                                  tooltip: '마지막 페이지',
                                  onPressed: canGoForward ? () => _loadPage(_totalPages - 1) : null,
                                  scheme: cs,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PagingMiniButton extends StatelessWidget {
  const _PagingMiniButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.scheme,
    this.compact = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;
  final ColorScheme scheme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: Size(compact ? 34 : 40, 40),
          padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: scheme.onSurface,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: compact ? -0.5 : 0,
          ),
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
    required this.scheme,
  });

  final String pageLabel;
  final bool selected;
  final VoidCallback? onPressed;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final cs = scheme;
    if (selected) {
      return Container(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          pageLabel,
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: cs.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(pageLabel),
    );
  }
}

class _BoardListItem {
  const _BoardListItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.dateLabel,
  });

  final int id;
  final String title;
  final String summary;
  final String dateLabel;
}

class _BoardListTile extends StatelessWidget {
  const _BoardListTile({required this.item});

  final _BoardListItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () {}, // 상세는 추후
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.dateLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
