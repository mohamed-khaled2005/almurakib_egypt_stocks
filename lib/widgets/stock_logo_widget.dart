import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/models/stock_model.dart';

class StockLogoWidget extends StatelessWidget {
  final StockModel? stock;
  final String? symbol;
  final String? logoUrl;
  final String? name;
  final double size;
  final double borderRadius;
  final bool showBorder;

  const StockLogoWidget({
    super.key,
    this.stock,
    this.symbol,
    this.logoUrl,
    this.name,
    this.size = 44,
    this.borderRadius = 10,
    this.showBorder = true,
  });

  String get _effectiveSymbol {
    if (symbol != null && symbol!.isNotEmpty) return symbol!;
    if (stock != null) {
      return stock!.symbol.isNotEmpty ? stock!.symbol : stock!.id;
    }
    return '';
  }

  String? get _effectiveLogoUrl {
    if (logoUrl != null && logoUrl!.trim().isNotEmpty) return logoUrl!.trim();
    if (stock != null &&
        stock!.selfLogo != null &&
        stock!.selfLogo!.trim().isNotEmpty) {
      return stock!.selfLogo!.trim();
    }
    return null;
  }

  String get _effectiveName {
    if (name != null && name!.isNotEmpty) return name!;
    if (stock != null) return stock!.displayName;
    return '';
  }

  String _safeInitials() {
    final sym = _effectiveSymbol.trim();
    final clean = sym.contains(':') ? sym.split(':').last.trim() : sym;
    if (clean.isNotEmpty) {
      return clean.length >= 2
          ? clean.substring(0, 2).toUpperCase()
          : clean.toUpperCase();
    }
    final n = _effectiveName.trim();
    if (n.isNotEmpty) {
      return n.length >= 2
          ? n.substring(0, 2).toUpperCase()
          : n.substring(0, 1).toUpperCase();
    }
    return '?';
  }

  Widget _buildFallbackInitials() {
    return Center(
      child: Text(
        _safeInitials(),
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.w900,
          color: const Color(0xFFC1121F),
          fontSize: size * 0.35,
        ),
      ),
    );
  }

  Widget _buildContent() {
    final sym = _effectiveSymbol.toUpperCase();
    final nameLower = _effectiveName.toLowerCase();

    // 1. CIB Custom Logo Widget
    if (sym.contains('COMI') ||
        nameLower.contains('commercial international bank')) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF003B70),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'CIB',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w900,
              fontSize: size * 0.27,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    // 2. National Foods Custom Logo Widget
    if (sym.contains('SNFI') ||
        nameLower.contains('souhag') ||
        nameLower.contains('national food')) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'National',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.17,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              Text(
                'Foods',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.15,
                  color: const Color(0xFFFEF08A),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final url = _effectiveLogoUrl;
    if (url != null && url.isNotEmpty) {
      if (url.toLowerCase().contains('.svg')) {
        return SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _buildFallbackInitials(),
        );
      }
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackInitials(),
      );
    }

    if (stock?.isIndex == true) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F2),
          borderRadius: BorderRadius.circular((borderRadius - 2).clamp(4, 20)),
        ),
        child: Center(
          child: Icon(
            Icons.show_chart_rounded,
            size: size * 0.52,
            color: const Color(0xFFC1121F),
          ),
        ),
      );
    }

    return _buildFallbackInitials();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: const Color(0xFFE5E7EB)) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }
}
