import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';

/// 마이페이지 화면
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nickname = CurrentUserHolder.nickname ?? '-';
    final email = CurrentUserHolder.email ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          Text(
            '내 정보',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: '닉네임', value: nickname),
          const SizedBox(height: 8),
          _InfoRow(label: '이메일', value: email),
          const SizedBox(height: 32),
          FilledButton.tonal(
            onPressed: () async {
              await TokenStorage.clearAll();
              CurrentUserHolder.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
