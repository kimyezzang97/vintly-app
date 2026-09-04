import 'package:flutter/material.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/report.dart';
import '../data/report_api.dart';

Future<void> showReportDialog(
  BuildContext context, {
  required ReportTargetType targetType,
  required int targetId,
}) async {
  final detailController = TextEditingController();
  final parentContext = context;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      ReportReason? selectedReason;
      var submitting = false;
      String? errorText;

      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            if (selectedReason == null) {
              setDialogState(() => errorText = '신고 사유를 선택해 주세요.');
              return;
            }
            if (submitting) return;
            setDialogState(() {
              submitting = true;
              errorText = null;
            });

            var dialogClosed = false;
            try {
              final response = await submitReport(
                AppConfig.instance.backend.baseUrl,
                targetType: targetType,
                targetId: targetId,
                reason: selectedReason!,
                detail: detailController.text,
              );
              if (!dialogContext.mounted) return;

              final code = response.code ?? response.statusCode;
              if (response.statusCode == 401 || code == 401) {
                dialogClosed = true;
                Navigator.of(dialogContext).pop();
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
                  () => errorText = _reportErrorMessage(code, response.msg),
                );
                return;
              }

              dialogClosed = true;
              Navigator.of(dialogContext).pop();
              if (!parentContext.mounted) return;
              ScaffoldMessenger.of(
                parentContext,
              ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
            } catch (_) {
              if (dialogContext.mounted) {
                setDialogState(
                  () => errorText = '신고 접수 중 오류가 발생했습니다. 다시 시도해 주세요.',
                );
              }
            } finally {
              if (!dialogClosed && dialogContext.mounted) {
                setDialogState(() => submitting = false);
              }
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text('신고하기'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${targetType.label} 신고 사유를 선택해 주세요.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ReportReason>(
                    initialValue: selectedReason,
                    decoration: const InputDecoration(
                      labelText: '신고 사유',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final reason in ReportReason.values)
                        DropdownMenuItem(
                          value: reason,
                          child: Text(reason.label),
                        ),
                    ],
                    onChanged: submitting
                        ? null
                        : (value) => setDialogState(() {
                            selectedReason = value;
                            errorText = null;
                          }),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: detailController,
                    enabled: !submitting,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: '상세 사유 (선택)',
                      hintText: '신고 사유를 자세히 작성해 주세요.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '신고 후에도 콘텐츠는 즉시 숨겨지지 않으며 운영자 검토를 위해 접수됩니다.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
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
                    : const Text('신고 접수'),
              ),
            ],
          );
        },
      );
    },
  );

  detailController.dispose();
}

String _reportErrorMessage(int code, String? serverMessage) {
  return switch (code) {
    409 => '이미 신고한 콘텐츠입니다.',
    403 => '본인이 작성한 콘텐츠는 신고할 수 없습니다.',
    404 => '신고 대상을 찾을 수 없습니다. 화면을 새로고침해 주세요.',
    _ => serverMessage ?? '신고 접수에 실패했습니다.',
  };
}
