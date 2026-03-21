import 'package:flutter/material.dart';

import '../features/mypage/presentation/mypage_screen.dart';
import '../features/vintage/presentation/vintage_list_screen.dart';

/// 하단 메뉴바가 있는 메인 쉘. Shop / MyPage 탭 전환.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<_TabItem> _tabs = [
    _TabItem(icon: Icons.store),
    _TabItem(icon: Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_tabs.length, (i) {
                final t = _tabs[i];
                final isSelected = _currentIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = i),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          t.icon,
                          color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon});
  final IconData icon;
}
