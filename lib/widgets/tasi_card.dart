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

  @override
  Widget build(BuildContext context) {
    final isGain = tasi.change >= 0;
    final isOpen = tasi.isOpen;

    final Color themeColor =
        isOpen ? (isGain ? AppColors.gain : AppColors.loss) : AppColors.neutral;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [
                      themeColor.withOpacity(0.04),
                      Colors.white,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -14,
              bottom: -14,
              child: Icon(
                Icons.show_chart_rounded,
                size: 86,
                color: themeColor.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.auto_graph_rounded,
                              color: isOpen
                                  ? AppColors.primaryBlue
                                  : AppColors.neutral,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المؤشر الرئيسي',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                              Text(
                                'EGX30',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      AppColors.textSecondary.withOpacity(0.5),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (onRefresh != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onRefresh,
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(
                                Icons.refresh_rounded,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Formatters.formatNumber(tasi.value),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _currency,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10.8,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
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
                              size: 14,
                              color: themeColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              Formatters.formatPercent(tasi.changePercent),
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: themeColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${Formatters.formatChange(tasi.change)} $_currency',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: themeColor,
                              ),
                            ),
                          ],
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
}
