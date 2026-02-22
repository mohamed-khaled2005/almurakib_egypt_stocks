// lib/widgets/tasi_card.dart
import 'package:flutter/material.dart';
import '../core/models/tasi_index_model.dart';
import '../core/utils/formatters.dart';
import '../core/utils/constants.dart';

class TasiCard extends StatelessWidget {
  final TasiIndexModel tasi;
  final VoidCallback? onRefresh;

  const TasiCard({
    super.key,
    required this.tasi,
    this.onRefresh,
  });

  // ✅ عرض المؤشر بعملة الدولة بدل "نقطة"
  static const String _currency = 'ج.م';

  bool _isEgxMarketOpen() {
    // ✅ EGX: Sunday -> Thursday
    // ✅ Hours (practical): 09:30 -> 14:30 Cairo time
    final now = DateTime.now(); // وقت الجهاز (مصر غالباً)

    final wd = now.weekday; // Mon=1 .. Sun=7
    final isTradingDay = (wd == DateTime.sunday) ||
        (wd >= DateTime.monday && wd <= DateTime.thursday);

    final minutes = now.hour * 60 + now.minute;
    const openMinutes = 9 * 60 + 30; // 09:30
    const closeMinutes = 14 * 60 + 30; // 14:30

    return isTradingDay && minutes >= openMinutes && minutes < closeMinutes;
  }

  String _fmtEgp(double v) => '${Formatters.formatNumber(v)} $_currency';

  @override
  Widget build(BuildContext context) {
    final isGain = tasi.change >= 0;
    final isOpen = _isEgxMarketOpen();

    // ✅ FIX: لون الكارت يبقى Neutral لو السوق مغلق
    final Color themeColor = isOpen
        ? (isGain ? AppColors.gain : AppColors.loss)
        : AppColors.neutral;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      themeColor.withOpacity(0.06),
                      Colors.white,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Icon(
                Icons.show_chart_rounded,
                size: 150,
                color: themeColor.withOpacity(0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.auto_graph_rounded,
                              color: isOpen
                                  ? AppColors.primaryBlue
                                  : AppColors.neutral,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المؤشر الرئيسي',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'EGX30',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textSecondary
                                      .withOpacity(0.5),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      _buildStatusBadge(isOpen),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Formatters.formatNumber(tasi.value),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ✅ بدل "نقطة" نخليها عملة الدولة
                      Text(
                        _currency,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isGain
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 18,
                              color: themeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              Formatters.formatPercent(tasi.changePercent),
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: themeColor,
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              width: 1,
                              height: 12,
                              color: themeColor.withOpacity(0.3),
                            ),
                            // ✅ change كمان يبقى بعملة الدولة
                            Text(
                              '${Formatters.formatChange(tasi.change)} $_currency',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (onRefresh != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onRefresh,
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isOpen) {
    final icon = isOpen ? Icons.lock_open_rounded : Icons.lock_rounded;

    final bg = isOpen
        ? AppColors.gain.withOpacity(0.10)
        : AppColors.neutral.withOpacity(0.10);

    final bd = isOpen
        ? AppColors.gain.withOpacity(0.20)
        : AppColors.neutral.withOpacity(0.20);

    final fg = isOpen ? AppColors.gain : AppColors.neutral;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: bd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'السوق مفتوح' : 'السوق مغلق',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
