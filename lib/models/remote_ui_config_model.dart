import 'manual_ad_model.dart';

class ManagedMenuCta {
  const ManagedMenuCta({
    required this.label,
    required this.url,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final String url;
  final String? backgroundColor;
  final String? textColor;

  bool get isUsable => label.trim().isNotEmpty && url.trim().isNotEmpty;

  factory ManagedMenuCta.fromJson(Map<String, dynamic> json) {
    return ManagedMenuCta(
      label: (json['label'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      backgroundColor: json['background_color']?.toString(),
      textColor: json['text_color']?.toString(),
    );
  }
}

class SocialLinkModel {
  const SocialLinkModel({
    required this.platform,
    required this.label,
    required this.url,
    required this.enabled,
  });

  final String platform;
  final String label;
  final String url;
  final bool enabled;

  bool get isUsable => enabled && url.trim().isNotEmpty;

  factory SocialLinkModel.fromJson(Map<String, dynamic> json) {
    return SocialLinkModel(
      platform: (json['platform'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      enabled: json['enabled'] == true,
    );
  }
}

class RemoteUiConfigModel {
  const RemoteUiConfigModel({
    required this.menuCta,
    required this.socialLinks,
    required this.popupAd,
  });

  final ManagedMenuCta? menuCta;
  final List<SocialLinkModel> socialLinks;
  final ManualAdModel? popupAd;

  factory RemoteUiConfigModel.empty() {
    return const RemoteUiConfigModel(
      menuCta: null,
      socialLinks: <SocialLinkModel>[],
      popupAd: null,
    );
  }

  factory RemoteUiConfigModel.fromJson(Map<String, dynamic> json) {
    final rawMenuCta = json['menu_cta'];
    final rawSocialLinks = json['social_links'];
    final rawPopupAd = json['popup_ad'];

    final ManagedMenuCta? menuCta = rawMenuCta is Map<String, dynamic>
        ? ManagedMenuCta.fromJson(rawMenuCta)
        : null;

    return RemoteUiConfigModel(
      menuCta: menuCta != null && menuCta.isUsable ? menuCta : null,
      socialLinks: rawSocialLinks is List
          ? rawSocialLinks
              .whereType<Map>()
              .map(
                (item) => SocialLinkModel.fromJson(item.cast<String, dynamic>()),
              )
              .where((item) => item.isUsable)
              .toList()
          : const <SocialLinkModel>[],
      popupAd: rawPopupAd is Map<String, dynamic>
          ? ManualAdModel.fromJson(rawPopupAd)
          : null,
    );
  }

  RemoteUiConfigModel copyWith({
    ManagedMenuCta? menuCta,
    List<SocialLinkModel>? socialLinks,
    ManualAdModel? popupAd,
    bool clearMenuCta = false,
    bool clearPopupAd = false,
  }) {
    return RemoteUiConfigModel(
      menuCta: clearMenuCta ? null : (menuCta ?? this.menuCta),
      socialLinks: socialLinks ?? this.socialLinks,
      popupAd: clearPopupAd ? null : (popupAd ?? this.popupAd),
    );
  }
}
