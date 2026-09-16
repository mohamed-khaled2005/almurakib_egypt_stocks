import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/constants.dart';
import '../models/manual_ad_model.dart';
import '../providers/app_manager_provider.dart';

class ManualAdBanner extends StatefulWidget {
  const ManualAdBanner({
    super.key,
    required this.ad,
    this.stickyBottom = false,
  });

  final ManualAdModel? ad;
  final bool stickyBottom;

  @override
  State<ManualAdBanner> createState() => _ManualAdBannerState();
}

class _ManualAdBannerState extends State<ManualAdBanner> {
  int? _trackedImpressionAdId;

  @override
  void initState() {
    super.initState();
    _trackVisibleAd();
  }

  @override
  void didUpdateWidget(covariant ManualAdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad?.id != widget.ad?.id) {
      _trackVisibleAd();
    }
  }

  void _trackVisibleAd() {
    final adData = widget.ad;
    if (adData == null ||
        adData.id <= 0 ||
        adData.imageUrl.isEmpty ||
        _trackedImpressionAdId == adData.id) {
      return;
    }

    _trackedImpressionAdId = adData.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppManagerProvider>().trackManualAd(
        ad: adData,
        eventType: 'impression',
        metadata: <String, dynamic>{'surface': 'manual_ad_banner'},
      );
    });
  }

  Future<void> _openAd(ManualAdModel adData) async {
    await context.read<AppManagerProvider>().trackManualAd(
      ad: adData,
      eventType: 'click',
      metadata: <String, dynamic>{'surface': 'manual_ad_banner'},
    );

    final uri = Uri.tryParse(adData.targetUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final adData = widget.ad;
    if (adData == null ||
        adData.imageUrl.isEmpty ||
        adData.placement.trim() != 'rectangle_main') {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final safeBottomInset = MediaQuery.paddingOf(context).bottom;
    final stickyImageHeight = (screenHeight * 0.15).clamp(54.0, 84.0);
    const regularImageHeight = 108.0;
    const BorderRadius bannerRadius = BorderRadius.all(Radius.circular(16));

    final double imageHeight =
        widget.stickyBottom ? stickyImageHeight : regularImageHeight;

    final Widget banner = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: bannerRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: bannerRadius,
        child: Material(
          color: AppColors.cardDark,
          child: InkWell(
            onTap: () => _openAd(adData),
            child: Image.network(
              adData.imageUrl,
              height: imageHeight,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  height: imageHeight,
                  width: double.infinity,
                  color: AppColors.cardLight,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (widget.stickyBottom) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          safeBottomInset > 0 ? safeBottomInset : 8,
        ),
        child: SizedBox(
          width: double.infinity,
          height: imageHeight,
          child: banner,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: banner,
    );
  }
}