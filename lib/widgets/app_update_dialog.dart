import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/constants.dart';
import '../models/remote_ui_config_model.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateConfig updateConfig;
  final VoidCallback? onDismiss;

  const AppUpdateDialog({
    super.key,
    required this.updateConfig,
    this.onDismiss,
  });

  static Future<void> showIfAvailable(
    BuildContext context,
    AppUpdateConfig config,
  ) async {
    if (!config.updateAvailable) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: !config.forceUpdate,
      builder: (ctx) => AppUpdateDialog(updateConfig: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = updateConfig.title?.trim().isNotEmpty == true
        ? updateConfig.title!
        : 'تحديث جديد متوفر';

    final message = updateConfig.message?.trim().isNotEmpty == true
        ? updateConfig.message!
        : 'يتوفر إصدار أحدث من التطبيق يتضمن تحسينات ومزايا جديدة. يرجى التحديث لتجربة أفضل.';

    return PopScope(
      canPop: !updateConfig.forceUpdate,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.system_update_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (updateConfig.latestVersion != null) ...[
              const SizedBox(height: 12),
              Text(
                'الإصدار الجديد: ${updateConfig.latestVersion}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!updateConfig.forceUpdate)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
              child: Text(
                'لاحقاً',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              final url = updateConfig.storeUrl?.trim();
              if (url != null && url.isNotEmpty) {
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
              if (!updateConfig.forceUpdate && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('تحديث الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
