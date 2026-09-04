import 'package:flutter/material.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/block_api.dart';

Future<bool> showBlockMemberDialog(
  BuildContext context, {
  required int memberId,
  required String nickname,
}) async {
  var submitting = false;
  String? errorText;
  final parentContext = context;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> submit() async {
          if (submitting) return;
          setDialogState(() {
            submitting = true;
            errorText = null;
          });
          var dialogClosed = false;
          try {
            final response = await blockMember(
              AppConfig.instance.backend.baseUrl,
              memberId,
            );
            if (!dialogContext.mounted) return;
            final code = response.code ?? response.statusCode;
            if (response.statusCode == 401 || code == 401) {
              dialogClosed = true;
              Navigator.of(dialogContext).pop(false);
              await TokenStorage.clearAll();
              CurrentUserHolder.clear();
              if (!parentContext.mounted) return;
              Navigator.of(
                parentContext,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
              return;
            }
            if (response.json['success'] != true) {
              setDialogState(
                () => errorText = response.msg ?? '사용자 차단에 실패했습니다.',
              );
              return;
            }
            dialogClosed = true;
            Navigator.of(dialogContext).pop(true);
          } catch (_) {
            if (dialogContext.mounted) {
              setDialogState(
                () => errorText = '사용자 차단 중 오류가 발생했습니다. 다시 시도해 주세요.',
              );
            }
          } finally {
            if (!dialogClosed && dialogContext.mounted) {
              setDialogState(() => submitting = false);
            }
          }
        }

        final displayName = nickname.trim().isEmpty ? '이 사용자' : nickname;
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('사용자 차단'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$displayName님을 차단할까요?'),
              const SizedBox(height: 10),
              const Text(
                '차단하면 이 사용자의 게시글과 댓글이 내 화면에서 보이지 않습니다. 상대방에게는 차단 사실이 알려지지 않습니다.',
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('차단'),
            ),
          ],
        );
      },
    ),
  );

  return result == true;
}
