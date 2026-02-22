import 'package:flutter/material.dart';

enum VintlyDialogType { success, error, info }

Future<void> showVintlyDialog(
  BuildContext context, {
  required VintlyDialogType type,
  String title = '안내',
  required String message,
  String confirmText = '확인',
  bool barrierDismissible = true,
}) async {
  final cs = Theme.of(context).colorScheme;

  final Color accent = switch (type) {
    VintlyDialogType.success => cs.secondary,
    VintlyDialogType.error => cs.error,
    VintlyDialogType.info => cs.primary,
  };

  final IconData icon = switch (type) {
    VintlyDialogType.success => Icons.check_circle_rounded,
    VintlyDialogType.error => Icons.error_rounded,
    VintlyDialogType.info => Icons.info_rounded,
  };

  await showDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(confirmText),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

