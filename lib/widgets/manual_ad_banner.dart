import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/constants.dart';
import '../models/manual_ad_model.dart';

class ManualAdBanner extends StatelessWidget {
  const ManualAdBanner({
    super.key,
    required this.ad,
    this.stickyBottom = false,
  });

  final ManualAdModel? ad;
  final bool stickyBottom;

  @override
  Widget build(BuildContext context) {
    final adData = ad;
    if (adData == null || adData.imageUrl.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;
    final imageHeight =
        stickyBottom ? (screenHeight * 0.15).clamp(58.0, 88.0) : 116.0;

    final banner = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () async {
              final uri = Uri.tryParse(adData.targetUrl.trim());
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: Image.network(
              adData.imageUrl,
              height: imageHeight,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: imageHeight,
                  width: double.infinity,
                  color: AppColors.cardLight,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(
                        Icons.campaign_outlined,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        adData.title.trim().isEmpty ? 'إعلان' : adData.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (stickyBottom) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          safeBottomInset > 0 ? safeBottomInset : 10,
        ),
        child: SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: banner,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: banner,
    );
  }
}
