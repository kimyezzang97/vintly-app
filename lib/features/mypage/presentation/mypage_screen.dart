import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';

const double _mypageDialogRadius = 28;

Widget _mypageColoredDialogTitle(BuildContext context, String title) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    decoration: BoxDecoration(
      color: cs.primary,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(_mypageDialogRadius),
        topRight: Radius.circular(_mypageDialogRadius),
      ),
    ),
    child: Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        color: cs.onPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _mypageDialogErrorBanner(BuildContext context, String message) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: cs.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 22,
            color: cs.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 마이페이지 화면
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nickname = CurrentUserHolder.nickname ?? '-';
    final email = CurrentUserHolder.email ?? '-';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Text(
            '내 정보',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(label: '닉네임', value: nickname),
          const SizedBox(height: 8),
          _InfoRow(label: '이메일', value: email),
          const SizedBox(height: 32),
          _SectionTitle(theme: theme, title: '계정'),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.badge_outlined,
            label: '닉네임 변경',
            onTap: () => _showChangeNicknameDialog(context),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.lock_outline,
            label: '비밀번호 변경',
            onTap: () => _showChangePasswordDialog(context),
          ),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.person_remove_outlined,
            label: '회원탈퇴',
            onTap: () => _showWithdrawAccountDialog(context),
          ),
          const SizedBox(height: 32),
          FilledButton.tonal(
            onPressed: () => _logout(context),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAuthFailure(BuildContext context) async {
    await TokenStorage.clearAll();
    CurrentUserHolder.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _showWithdrawAccountDialog(BuildContext context) async {
    final baseUrl = AppConfig.instance.backend.baseUrl;
    const path = '/api/v1/members/me';
    final passwordCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      // 바깥 탭으로 닫으면 포커스 해제와 라우트 dispose 순서가 겹쳐 framework assertion 이 날 수 있음
      barrierDismissible: false,
      builder: (_) {
        var submitting = false;
        String? errorText;
        var obscurePassword = true;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> submit() async {
              final password = passwordCtrl.text;
              if (password.isEmpty) {
                setSt(() => errorText = '비밀번호를 입력해 주세요.');
                return;
              }
              if (submitting) return;
              setSt(() {
                errorText = null;
                submitting = true;
              });
              var routePopped = false;
              try {
                final response = await deleteWithAuth(
                  baseUrl,
                  path,
                  body: {'password': password},
                );
                if (!ctx.mounted) return;
                final success = response.json['success'] == true;
                if (!success) {
                  setSt(() => errorText = response.msg ?? '회원탈퇴에 실패했습니다.');
                  return;
                }
                routePopped = true;
                Navigator.of(ctx).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!context.mounted) return;
                  await TokenStorage.clearAll();
                  CurrentUserHolder.clear();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('회원탈퇴가 처리되었습니다.')),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                    (route) => false,
                  );
                });
              } catch (_) {
                setSt(() => errorText = '오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
              } finally {
                if (!routePopped && ctx.mounted) {
                  setSt(() => submitting = false);
                }
              }
            }

            final cs = Theme.of(ctx).colorScheme;
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(_mypageDialogRadius)),
              ),
              titlePadding: EdgeInsets.zero,
              title: _mypageColoredDialogTitle(ctx, '회원탈퇴'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorText != null && errorText!.isNotEmpty) ...[
                      _mypageDialogErrorBanner(ctx, errorText!),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      '탈퇴 시 계정과 관련 데이터가 삭제되며 복구할 수 없습니다. 계속하시겠습니까?',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      enabled: !submitting,
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: submitting
                              ? null
                              : () => setSt(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  onPressed: submitting ? null : () => submit(),
                  child: submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onError,
                          ),
                        )
                      : const Text('탈퇴하기'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      passwordCtrl.dispose();
    });
  }

  Future<void> _showChangeNicknameDialog(BuildContext context) async {
    final controller = TextEditingController(text: CurrentUserHolder.nickname ?? '');
    final baseUrl = AppConfig.instance.backend.baseUrl;
    const path = '/api/v1/members/me/nickname';
    final parentContext = context;

    await showDialog<void>(
      context: context,
      builder: (_) {
        var submitting = false;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> submit() async {
              final n = controller.text.trim();
              if (n.isEmpty) {
                setDialogState(() => errorText = '닉네임을 입력해 주세요.');
                return;
              }
              if (submitting) return;
              setDialogState(() {
                errorText = null;
                submitting = true;
              });
              var routePopped = false;
              try {
                final response = await patchJsonWithAuth(
                  baseUrl,
                  path,
                  body: {'nickname': n},
                );
                if (!ctx.mounted) return;
                final code = response.code ?? response.statusCode;
                if (response.statusCode == 401 || code == 401 || response.statusCode == 403) {
                  routePopped = true;
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!parentContext.mounted) return;
                    await _handleAuthFailure(parentContext);
                  });
                  return;
                }
                final success = response.json['success'] == true;
                if (!success) {
                  setDialogState(() => errorText = response.msg ?? '닉네임 변경에 실패했습니다.');
                  return;
                }
                final refreshed = await fetchAndSetCurrentUser(baseUrl);
                if (!ctx.mounted) return;
                if (!refreshed) {
                  routePopped = true;
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (!parentContext.mounted) return;
                    await _handleAuthFailure(parentContext);
                  });
                  return;
                }
                routePopped = true;
                Navigator.of(ctx).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('닉네임이 변경되었습니다.')),
                  );
                });
              } catch (_) {
                setDialogState(() => errorText = '오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
              } finally {
                if (!routePopped && ctx.mounted) {
                  setDialogState(() => submitting = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(_mypageDialogRadius)),
              ),
              titlePadding: EdgeInsets.zero,
              title: _mypageColoredDialogTitle(ctx, '닉네임 변경'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorText != null && errorText!.isNotEmpty) ...[
                      _mypageDialogErrorBanner(ctx, errorText!),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      '닉네임은 마지막 변경일로부터 14일 이후에 다시 변경할 수 있습니다.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      enabled: !submitting,
                      decoration: const InputDecoration(
                        labelText: '새 닉네임',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 30,
                      buildCounter: (
                        context, {
                        required int currentLength,
                        required bool isFocused,
                        required int? maxLength,
                      }) =>
                          null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: submitting ? null : () => submit(),
                  child: submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(ctx).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('변경'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final baseUrl = AppConfig.instance.backend.baseUrl;
    const path = '/api/v1/members/me/password';

    await showDialog<void>(
      context: context,
      builder: (_) {
        bool obscureCurrent = true;
        bool obscureNew = true;
        bool obscureConfirm = true;
        var submitting = false;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> submit() async {
              final cur = currentCtrl.text;
              final nw = newCtrl.text;
              final chk = confirmCtrl.text;
              if (cur.isEmpty || nw.isEmpty || chk.isEmpty) {
                setSt(() => errorText = '모든 항목을 입력해 주세요.');
                return;
              }
              if (nw != chk) {
                setSt(() => errorText = '새 비밀번호와 확인이 일치하지 않습니다.');
                return;
              }
              if (submitting) return;
              setSt(() {
                errorText = null;
                submitting = true;
              });
              var routePopped = false;
              try {
                final response = await patchJsonWithAuth(
                  baseUrl,
                  path,
                  body: {
                    'currentPassword': cur,
                    'newPassword': nw,
                  },
                );
                if (!ctx.mounted) return;
                // 비밀번호 오류 등으로 서버가 401/403을 주는 경우가 많아, 여기서는 로그아웃하지 않음
                final success = response.json['success'] == true;
                if (!success) {
                  setSt(() => errorText = response.msg ?? '비밀번호 변경에 실패했습니다.');
                  return;
                }
                routePopped = true;
                Navigator.of(ctx).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
                  );
                });
              } catch (_) {
                setSt(() => errorText = '오류가 발생했습니다. 잠시 후 다시 시도해 주세요.');
              } finally {
                if (!routePopped && ctx.mounted) {
                  setSt(() => submitting = false);
                }
              }
            }

            final screenW = MediaQuery.sizeOf(ctx).width;
            const horizontalInset = 16.0;
            final dialogMaxW = screenW - horizontalInset * 2;
            const passwordDialogMinW = 348.0;
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: horizontalInset, vertical: 24),
              constraints: BoxConstraints(
                minWidth: math.min(passwordDialogMinW, dialogMaxW),
                maxWidth: dialogMaxW,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(_mypageDialogRadius)),
              ),
              titlePadding: EdgeInsets.zero,
              title: _mypageColoredDialogTitle(ctx, '비밀번호 변경'),
              contentPadding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (errorText != null && errorText!.isNotEmpty) ...[
                      _mypageDialogErrorBanner(ctx, errorText!),
                      const SizedBox(height: 18),
                    ],
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      enabled: !submitting,
                      decoration: InputDecoration(
                        labelText: '현재 비밀번호',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: submitting
                              ? null
                              : () => setSt(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      enabled: !submitting,
                      decoration: InputDecoration(
                        labelText: '새 비밀번호',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: submitting ? null : () => setSt(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      enabled: !submitting,
                      decoration: InputDecoration(
                        labelText: '새 비밀번호 확인',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: submitting
                              ? null
                              : () => setSt(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: submitting ? null : () => submit(),
                  child: submitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(ctx).colorScheme.onPrimary,
                          ),
                        )
                      : const Text('변경'),
                ),
              ],
            );
          },
        );
      },
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: cs.outline.withValues(alpha: 0.4), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.logout_rounded, size: 40, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  '로그아웃',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '로그아웃 하시겠습니까?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
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
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                        ),
                        child: const Text('확인'),
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
    if (confirmed != true || !context.mounted) return;
    await TokenStorage.clearAll();
    CurrentUserHolder.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.theme, required this.title});

  final ThemeData theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(width: 14),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 22, color: cs.outline),
            ],
          ),
        ),
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
