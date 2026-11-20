import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../models/manual_ad_model.dart';
import '../providers/app_manager_provider.dart';

class AdBannerCard extends StatefulWidget {
  final VoidCallback? onClose;

  const AdBannerCard({super.key, this.onClose});

  @override
  State<AdBannerCard> createState() => _AdBannerCardState();
}

class _AdBannerCardState extends State<AdBannerCard> {
  bool _dismissed = false;
  int? _trackedImpressionAdId;

  void _trackImpression(ManualAdModel? ad, AppManagerProvider manager) {
    if (ad == null || ad.id <= 0 || _trackedImpressionAdId == ad.id) return;
    _trackedImpressionAdId = ad.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      manager.trackManualAd(
        ad: ad,
        eventType: 'impression',
        metadata: <String, dynamic>{'surface': 'ad_banner_card'},
      );
    });
  }

  void _handleAdClick(ManualAdModel? ad, String url, AppManagerProvider manager) async {
    if (ad != null && ad.id > 0) {
      await manager.trackManualAd(
        ad: ad,
        eventType: 'click',
        metadata: <String, dynamic>{'surface': 'ad_banner_card'},
      );
    }
    final uri = Uri.tryParse(url.trim());
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _handleAdDismiss(ManualAdModel? ad, AppManagerProvider manager) {
    setState(() => _dismissed = true);
    if (ad != null && ad.id > 0) {
      manager.trackManualAd(
        ad: ad,
        eventType: 'dismiss',
        metadata: <String, dynamic>{'surface': 'ad_banner_card'},
      );
    }
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final manager = context.watch<AppManagerProvider>();
    final activeAd = manager.activeAd;

    // Track impression if active ad is present
    if (activeAd != null) {
      _trackImpression(activeAd, manager);
    }

    // If it's an image ad and has a valid image URL
    if (activeAd != null && activeAd.isImageAd && activeAd.imageUrl.isNotEmpty) {
      return _buildImageAd(context, activeAd, manager);
    }

    // Default or configured Text Ad
    return _buildTextAd(context, activeAd, manager);
  }

  Widget _buildImageAd(
    BuildContext context,
    ManualAdModel ad,
    AppManagerProvider manager,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            InkWell(
              onTap: () => _handleAdClick(ad, ad.targetUrl, manager),
              child: Image.network(
                ad.imageUrl,
                height: 80,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildTextAd(context, ad, manager),
              ),
            ),
            // Close button top-left
            Positioned(
              top: 6,
              left: 6,
              child: InkWell(
                onTap: () => _handleAdDismiss(ad, manager),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextAd(
    BuildContext context,
    ManualAdModel? ad,
    AppManagerProvider manager,
  ) {
    final String title = (ad != null && ad.title.trim().isNotEmpty)
        ? ad.title.trim()
        : 'شركة الأمل للوساطة';
    final String subtitle = (ad != null && ad.subtitle != null && ad.subtitle!.trim().isNotEmpty)
        ? ad.subtitle!.trim()
        : 'ابدأ التداول في البورصة المصرية';
    final String targetUrl = (ad != null && ad.targetUrl.trim().isNotEmpty)
        ? ad.targetUrl.trim()
        : 'https://almurakib.com';
    final String actionText = (ad != null && ad.buttonText.trim().isNotEmpty)
        ? ad.buttonText.trim()
        : 'افتح حساب';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Content (Right in RTL)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'إعلان',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Actions (Left in RTL): Button then Close icon
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () => _handleAdClick(ad, targetUrl, manager),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC1121F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _handleAdDismiss(ad, manager),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFF9CA3AF),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
