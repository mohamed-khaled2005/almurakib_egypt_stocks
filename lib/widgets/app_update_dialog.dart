import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/remote_ui_config_model.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateConfig updateConfig;
  final VoidCallback? onDismiss;

  const AppUpdateDialog({
    super.key,
    required this.updateConfig,
    this.onDismiss,
  });

  static bool _isShowing = false;
  static bool _dismissedInSession = false;
  static const String currentAppVersion = '1.0.0';

  static int _compareVersions(String v1, String v2) {
    List<int> parse(String v) {
      final clean = v.split('+').first.replaceAll(RegExp(r'[^\d\.]'), '');
      if (clean.isEmpty) return [0];
      return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    }
    final p1 = parse(v1);
    final p2 = parse(v2);
    final maxLen = p1.length > p2.length ? p1.length : p2.length;
    for (int i = 0; i < maxLen; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 != n2) return n1.compareTo(n2);
    }
    return 0;
  }

  static Future<void> showIfAvailable(
    BuildContext context,
    AppUpdateConfig config,
  ) async {
    if (!config.updateAvailable) return;
    if (_isShowing) return;

    final latest = config.latestVersion?.trim();
    if (latest != null && latest.isNotEmpty) {
      // If current app version is equal or higher than latestVersion, no update needed!
      if (_compareVersions(currentAppVersion, latest) >= 0) {
        return;
      }
    }

    bool isForced = config.forceUpdate;
    final minVer = config.minVersion?.trim();
    if (minVer != null && minVer.isNotEmpty) {
      if (_compareVersions(currentAppVersion, minVer) < 0) {
        isForced = true;
      }
    }

    // If it's an optional update and user already dismissed it this session, don't re-open!
    if (!isForced && _dismissedInSession) {
      return;
    }

    final effectiveConfig = isForced && !config.forceUpdate
        ? config.copyWith(forceUpdate: true)
        : config;

    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !effectiveConfig.forceUpdate,
        builder: (ctx) => AppUpdateDialog(
          updateConfig: effectiveConfig,
          onDismiss: () {
            _dismissedInSession = true;
          },
        ),
      );
    } catch (_) {
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = updateConfig.title?.trim().isNotEmpty == true
        ? updateConfig.title!
        : 'إصدار جديد';

    final message = updateConfig.message?.trim().isNotEmpty == true
        ? updateConfig.message!
        : 'هناك إصدار جديد للتطبيق. قم بالتحديث الآن';

    return PopScope(
      canPop: !updateConfig.forceUpdate,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Download Icon (Matches Images 2 & 3)
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E8),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.file_download_outlined,
                    size: 28,
                    color: Color(0xFFC1121F),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title: إصدار جديد
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Primary Button: تحديث الآن (Matches Images 2 & 3)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
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
                    backgroundColor: const Color(0xFFC1121F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'تحديث الآن',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              // Secondary Button: لاحقاً (Shown only for Optional Update - Image 3)
              if (!updateConfig.forceUpdate) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDismiss?.call();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'لاحقاً',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
