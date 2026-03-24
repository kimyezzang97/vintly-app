import 'package:flutter/material.dart';

import '../features/mypage/presentation/mypage_screen.dart';
import '../features/vintage/presentation/vintage_list_screen.dart';

/// 하단 메뉴바가 있는 메인 쉘. Shop / (게시판 자리, 미연동) / MyPage.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          VintageListScreen(),
          MyPageScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        color: cs.surfaceContainerHighest,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: _NavTab(
                    icon: Icons.store,
                    selected: _currentIndex == 0,
                    colorScheme: cs,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Icon(
                      Icons.article_outlined,
                      color: cs.onSurfaceVariant,
                      size: 26,
                    ),
                  ),
                ),
                Expanded(
                  child: _NavTab(
                    icon: Icons.person,
                    selected: _currentIndex == 1,
                    colorScheme: cs,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.selected,
    required this.colorScheme,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return InkWell(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
    );
  }
}
