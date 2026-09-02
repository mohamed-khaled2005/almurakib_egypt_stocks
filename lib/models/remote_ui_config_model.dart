import 'manual_ad_model.dart';

class ManagedAppListing {
  const ManagedAppListing({
    required this.slug,
    required this.name,
    required this.nameEn,
    required this.playStoreUrl,
    required this.appStoreUrl,
    required this.logoUrl,
    required this.sortOrder,
  });

  final String slug;
  final String name;
  final String? nameEn;
  final String? playStoreUrl;
  final String? appStoreUrl;
  final String logoUrl;
  final int sortOrder;

  bool get hasPlayStoreUrl => (playStoreUrl ?? '').trim().isNotEmpty;
  bool get hasAppStoreUrl => (appStoreUrl ?? '').trim().isNotEmpty;

  String? urlFor({required bool useAppStore}) {
    final value = useAppStore ? appStoreUrl : playStoreUrl;
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  factory ManagedAppListing.fromJson(Map<String, dynamic> json) {
    return ManagedAppListing(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      nameEn: json['name_en']?.toString(),
      playStoreUrl: json['play_store_url']?.toString(),
      appStoreUrl: json['app_store_url']?.toString(),
      logoUrl: (json['logo_url'] ?? '').toString(),
      sortOrder: int.tryParse((json['sort_order'] ?? 0).toString()) ?? 0,
    );
  }
}

class FacebookSdkConfig {
  const FacebookSdkConfig({
    required this.enabled,
    required this.appId,
    required this.clientToken,
    required this.autoLogAppEvents,
  });

  final bool enabled;
  final String? appId;
  final String? clientToken;
  final bool autoLogAppEvents;

  bool get isUsable =>
      enabled &&
      (appId ?? '').trim().isNotEmpty &&
      (clientToken ?? '').trim().isNotEmpty;

  factory FacebookSdkConfig.disabled() {
    return const FacebookSdkConfig(
      enabled: false,
      appId: null,
      clientToken: null,
      autoLogAppEvents: false,
    );
  }

  factory FacebookSdkConfig.fromJson(Map<String, dynamic> json) {
    return FacebookSdkConfig(
      enabled: json['enabled'] == true,
      appId: json['app_id']?.toString(),
      clientToken: json['client_token']?.toString(),
      autoLogAppEvents: json['auto_log_app_events'] == true,
    );
  }
}

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
    required this.ourApps,
    required this.facebookSdk,
    required this.popupAd,
  });

  final ManagedMenuCta? menuCta;
  final List<SocialLinkModel> socialLinks;
  final List<ManagedAppListing> ourApps;
  final FacebookSdkConfig facebookSdk;
  final ManualAdModel? popupAd;

  factory RemoteUiConfigModel.empty() {
    return RemoteUiConfigModel(
      menuCta: null,
      socialLinks: const <SocialLinkModel>[],
      ourApps: const <ManagedAppListing>[],
      facebookSdk: FacebookSdkConfig.disabled(),
      popupAd: null,
    );
  }

  factory RemoteUiConfigModel.fromJson(Map<String, dynamic> json) {
    final rawMenuCta = json['menu_cta'];
    final rawSocialLinks = json['social_links'];
    final rawOurApps = json['our_apps'];
    final rawFacebookSdk = json['facebook_sdk'];
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
                (item) =>
                    SocialLinkModel.fromJson(item.cast<String, dynamic>()),
              )
              .where((item) => item.isUsable)
              .toList()
          : const <SocialLinkModel>[],
      ourApps: rawOurApps is List
          ? rawOurApps
              .whereType<Map>()
              .map((item) =>
                  ManagedAppListing.fromJson(item.cast<String, dynamic>()))
              .where(
                (item) =>
                    item.name.trim().isNotEmpty &&
                    item.logoUrl.trim().isNotEmpty &&
                    (item.hasPlayStoreUrl || item.hasAppStoreUrl),
              )
              .toList()
          : const <ManagedAppListing>[],
      facebookSdk: rawFacebookSdk is Map<String, dynamic>
          ? FacebookSdkConfig.fromJson(rawFacebookSdk)
          : FacebookSdkConfig.disabled(),
      popupAd: rawPopupAd is Map<String, dynamic>
          ? ManualAdModel.fromJson(rawPopupAd)
          : null,
    );
  }

  RemoteUiConfigModel copyWith({
    ManagedMenuCta? menuCta,
    List<SocialLinkModel>? socialLinks,
    List<ManagedAppListing>? ourApps,
    FacebookSdkConfig? facebookSdk,
    ManualAdModel? popupAd,
    bool clearMenuCta = false,
    bool clearPopupAd = false,
  }) {
    return RemoteUiConfigModel(
      menuCta: clearMenuCta ? null : (menuCta ?? this.menuCta),
      socialLinks: socialLinks ?? this.socialLinks,
      ourApps: ourApps ?? this.ourApps,
      facebookSdk: facebookSdk ?? this.facebookSdk,
      popupAd: clearPopupAd ? null : (popupAd ?? this.popupAd),
    );
  }
}