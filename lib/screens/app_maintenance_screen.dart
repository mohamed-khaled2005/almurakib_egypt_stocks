import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_manager_provider.dart';

class AppMaintenanceScreen extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  const AppMaintenanceScreen({
    super.key,
    this.title,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppManagerProvider>();
    final displayTitle = title?.trim().isNotEmpty == true
        ? title!
        : 'التطبيق تحت الصيانة';
    final displayMessage = message?.trim().isNotEmpty == true
        ? message!
        : 'نقوم حالياً بتحسين الخدمة وسنعود قريباً.';

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () async {
            if (onRetry != null) {
              onRetry!();
            } else {
              await provider.refreshRemoteUiConfig();
            }
          },
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular Icon Container (Matches Image 1)
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.build_rounded,
                        size: 32,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title (Matches Image 1)
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle (Matches Image 1)
                  Text(
                    displayMessage,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
