import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';

const double _mypageDialogRadius = 22;
const Color _mypageInk = Color(0xFF241A17);
const Color _mypageEspresso = Color(0xFF3B241C);
const Color _mypageCaramel = Color(0xFFA96F3D);
const Color _mypageBackground = Color(0xFFF4F3F1);
const Color _mypageMuted = Color(0xFF8A817D);

Widget _mypageColoredDialogTitle(BuildContext context, String title) {
  final theme = Theme.of(context);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(_mypageDialogRadius),
        topRight: Radius.circular(_mypageDialogRadius),
      ),
    ),
    child: Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        color: _mypageInk,
        fontWeight: FontWeight.w800,
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
    final nickname = CurrentUserHolder.nickname ?? '-';
    final email = CurrentUserHolder.email ?? '-';
    final initial = nickname == '-' || nickname.isEmpty
        ? '?'
        : nickname.substring(0, 1).toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: _mypageBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 18,
              20,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VINTLY',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _mypageCaramel,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '마이',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: _mypageEspresso,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE8E3DF)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFF2E7DC),
                        foregroundColor: _mypageEspresso,
                        child: Text(
                          initial,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: _mypageInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _mypageMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const _SectionTitle(title: '계정 설정'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE8E3DF)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.badge_outlined,
                        label: '닉네임 변경',
                        onTap: () => _showChangeNicknameDialog(context),
                      ),
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: Color(0xFFE8E1DA),
                      ),
                      _MenuItem(
                        icon: Icons.lock_outline_rounded,
                        label: '비밀번호 변경',
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      const Divider(
                        height: 1,
                        indent: 56,
                        color: Color(0xFFE8E1DA),
                      ),
                      _MenuItem(
                        icon: Icons.person_remove_outlined,
                        label: '회원탈퇴',
                        destructive: true,
                        onTap: () => _showWithdrawAccountDialog(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5F5652),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD8CEC6)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 19),
                  label: const Text(
                    '로그아웃',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(_mypageDialogRadius)),
                side: BorderSide(color: Color(0xFFE8E1DA)),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF3D0D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 21,
                            color: Color(0xFFC94848),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '탈퇴 시 계정과 관련 데이터가 삭제되며 복구할 수 없습니다.',
                              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF7A3E3E),
                                    height: 1.45,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      enabled: !submitting,
                      decoration: _mypageDialogFieldDecoration(
                        label: '비밀번호 확인',
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
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(foregroundColor: _mypageMuted),
                  child: const Text('취소'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC94848),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitting ? null : () => submit(),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
                side: BorderSide(color: Color(0xFFE8E1DA)),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F2EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 19,
                            color: _mypageCaramel,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '닉네임은 마지막 변경일로부터 14일 이후에 다시 변경할 수 있습니다.',
                              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF6F6560),
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      enabled: !submitting,
                      decoration: _mypageDialogFieldDecoration(
                        label: '새 닉네임',
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
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(foregroundColor: _mypageMuted),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: submitting ? null : () => submit(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF35424A),
                    foregroundColor: Colors.white,
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
                side: BorderSide(color: Color(0xFFE8E1DA)),
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
                      decoration: _mypageDialogFieldDecoration(
                        label: '현재 비밀번호',
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
                      decoration: _mypageDialogFieldDecoration(
                        label: '새 비밀번호',
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
                      decoration: _mypageDialogFieldDecoration(
                        label: '새 비밀번호 확인',
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
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(foregroundColor: _mypageMuted),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: submitting ? null : () => submit(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF35424A),
                    foregroundColor: Colors.white,
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
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
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_mypageDialogRadius),
            side: const BorderSide(color: Color(0xFFE8E1DA)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2E7DC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    size: 25,
                    color: Color(0xFF35424A),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '로그아웃',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: _mypageInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '로그아웃 하시겠습니까?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _mypageMuted,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _mypageMuted,
                          side: const BorderSide(color: Color(0xFFD8CEC6)),
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
                          backgroundColor: const Color(0xFF35424A),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('로그아웃'),
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
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: _mypageInk,
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: destructive
                    ? const Color(0xFFC94848)
                    : const Color(0xFF35424A),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: destructive
                      ? const Color(0xFFC94848)
                      : _mypageInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFFB6AAA2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _mypageDialogFieldDecoration({
  required String label,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _mypageMuted),
    filled: true,
    fillColor: const Color(0xFFF7F6F4),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE8E1DA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE8E1DA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _mypageCaramel, width: 1.5),
    ),
    suffixIcon: suffixIcon,
  );
}
