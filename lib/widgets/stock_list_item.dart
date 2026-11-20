import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/models/stock_model.dart';
import '../core/utils/formatters.dart';
import 'live_price_flash_container.dart';
import 'triangle_arrow.dart';
import 'chevron_left_icon.dart';

class StockListItem extends StatelessWidget {
  final StockModel stock;
  final VoidCallback? onTap;
  final bool showFavoriteButton;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final String? customBadgeText;
  final Color? customBadgeColor;
  final Color? customBadgeBgColor;
  final IconData? customBadgeIcon;

  const StockListItem({
    super.key,
    required this.stock,
    this.onTap,
    this.showFavoriteButton = true,
    this.isFavorite = false,
    this.onFavoriteTap,
    this.customBadgeText,
    this.customBadgeColor,
    this.customBadgeBgColor,
    this.customBadgeIcon,
  });

  static const String _currency = 'ج.م';

  bool _isSvg(String url) => url.toLowerCase().contains('.svg');

  String _safeInitials() {
    final raw = (stock.symbol.isNotEmpty ? stock.symbol : stock.id).trim();
    if (raw.isEmpty) return '?';
    final cleaned = raw.contains(':') ? raw.split(':').last.trim() : raw;
    if (cleaned.isEmpty) return '?';
    return cleaned.length >= 2 ? cleaned.substring(0, 2) : cleaned.substring(0, 1);
  }

  Widget _buildLogoFallback() {
    return Center(
      child: Text(
        _safeInitials(),
        style: const TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w900,
          color: Color(0xFFC1121F),
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildCompanyLogo() {
    final url = stock.selfLogo?.trim();
    if (url == null || url.isEmpty) return _buildLogoFallback();

    if (_isSvg(url)) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFC1121F),
            ),
          ),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _buildLogoFallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFC1121F),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge() {
    if (customBadgeText != null && customBadgeText!.isNotEmpty) {
      final color = customBadgeColor ?? const Color(0xFF9333EA);
      final bg = customBadgeBgColor ?? const Color(0xFFF3E8FF);
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              customBadgeText!,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (customBadgeIcon != null) ...[
              const SizedBox(width: 4),
              Icon(customBadgeIcon, size: 12, color: color),
            ],
          ],
        ),
      );
    }

    if (stock.isReit) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: const Row(
          textDirection: TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ريت',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF0284C7)),
          ],
        ),
      );
    }

    if (stock.isEtf || stock.isFund) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF3E8FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD8B4FE)),
        ),
        child: const Row(
          textDirection: TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'يتبع EGX 30',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9333EA),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.trending_up_rounded, size: 12, color: Color(0xFF9333EA)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isGain = stock.changePercent > 0;
    final isZero = stock.changePercent == 0;
    final changeBg = isZero
        ? const Color(0xFFF1F5F9)
        : (isGain ? const Color(0xFFDCFCE7) : const Color(0xFFFDE8E8));
    final changeColor = isZero
        ? const Color(0xFF64748B)
        : (isGain ? const Color(0xFF15803D) : const Color(0xFF991B1B));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: LivePriceFlashContainer(
            price: stock.price,
            enabled: stock.canUseWebSocket,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // 1. Right: Company Logo Container
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildCompanyLogo(),
                ),

                const SizedBox(width: 12),

                // 2. Middle: Name, Symbol, and optional Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stock.displayName,
                        maxLines: 5,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: Color(0xFF111827),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stock.displaySymbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      _buildBadge(),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // 3. Left: Price and Change Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Formatters.formatNumber(stock.price),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          _currency,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Pill under price: capsule rounded with bold solid triangle and percentage (e.g. 5.06%-)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: changeBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.ltr,
                        children: [
                          if (!isZero) ...[
                            TriangleArrow(
                              isUp: isGain,
                              color: changeColor,
                              width: 10,
                              height: 8,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            Formatters.formatPillPercent(stock.changePercent),
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: changeColor,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 4. Far Left: Favorite button & chevron pointing strictly LEFT
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showFavoriteButton)
                      InkWell(
                        onTap: onFavoriteTap,
                        borderRadius: BorderRadius.circular(50),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                            color: isFavorite ? const Color(0xFFF59E0B) : const Color(0xFF9CA3AF),
                            size: 20,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 20),
                    const SizedBox(height: 6),
                    // Chevron pointing strictly to the LEFT (الشمال) <
                    const ChevronLeftIcon(
                      color: Color(0xFF9CA3AF),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
