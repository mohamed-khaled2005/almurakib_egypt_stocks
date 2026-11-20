class ManualAdModel {
  final int id;
  final String adType; // 'text' or 'image'
  final String title;
  final String? subtitle;
  final String buttonText;
  final String targetUrl;
  final String imageUrl;
  final String platform;
  final String placement;
  final bool dismissOnce;

  const ManualAdModel({
    required this.id,
    this.adType = 'image',
    required this.title,
    this.subtitle,
    this.buttonText = 'افتح حساب',
    required this.targetUrl,
    required this.imageUrl,
    required this.platform,
    required this.placement,
    this.dismissOnce = false,
  });

  bool get isTextAd =>
      adType == 'text' || (imageUrl.isEmpty && (subtitle != null || title.isNotEmpty));
  bool get isImageAd => !isTextAd && imageUrl.isNotEmpty;

  factory ManualAdModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['ad_type'] ?? '').toString().trim().toLowerCase();
    final rawImageUrl = (json['image_url'] ?? '').toString().trim();
    final resolvedType = rawType.isNotEmpty
        ? rawType
        : (rawImageUrl.isEmpty ? 'text' : 'image');

    return ManualAdModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      adType: resolvedType,
      title: (json['title'] ?? '').toString(),
      subtitle: json['subtitle']?.toString(),
      buttonText: (json['button_text'] ?? '').toString().trim().isNotEmpty
          ? (json['button_text']).toString().trim()
          : 'افتح حساب',
      targetUrl: (json['target_url'] ?? '').toString(),
      imageUrl: rawImageUrl,
      platform: (json['platform'] ?? '').toString(),
      placement: (json['placement'] ?? '').toString(),
      dismissOnce: json['dismiss_once'] == true || json['dismiss_once'] == 1,
    );
  }
}
