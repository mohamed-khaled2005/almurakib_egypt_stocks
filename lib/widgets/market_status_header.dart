import 'dart:async';
import 'package:flutter/material.dart';

import '../core/models/market_status_model.dart';
import '../core/services/stock_service.dart';

class MarketStatusHeader extends StatefulWidget {
  final VoidCallback? onRefresh;
  final bool compact;

  const MarketStatusHeader({
    super.key,
    this.onRefresh,
    this.compact = false,
  });

  @override
  State<MarketStatusHeader> createState() => _MarketStatusHeaderState();
}

class _MarketStatusHeaderState extends State<MarketStatusHeader> {
  late MarketStatusModel _status;
  Timer? _countdownTimer;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _status = MarketStatusModel.calculateCurrentStatus();
    _loadStatus();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _status = MarketStatusModel.calculateCurrentStatus();
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await StockService.getMarketStatus();
      if (mounted) {
        setState(() {
          _status = res;
          _lastUpdateTime = DateTime.now();
        });
      }
    } catch (_) {}
  }

  String _formatDateAndTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return 'آخر تحديث $d/$m/$y • $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final isOpen = status.isOpen;

    // Compact layout (Matches Stock & Index Details top bar in Image 2)
    if (widget.compact) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          textDirection: TextDirection.rtl,
          children: [
            // Right: Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOpen ? const Color(0xFFE8F8F0) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: isOpen
                    ? Border.all(color: const Color(0xFFBBF7D0))
                    : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOpen) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'السوق مفتوح • يغلق 14:30',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'السوق مغلق',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Center: Last update text
            Text(
              _formatDateAndTime(_lastUpdateTime),
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w500,
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),

            // Left: Refresh Icon Button
            InkWell(
              onTap: () {
                setState(() {
                  _lastUpdateTime = DateTime.now();
                });
                _loadStatus();
                widget.onRefresh?.call();
              },
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Color(0xFFC1121F),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default layout (Matches Home Header in Image 1)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Right in RTL: Market Status Pill + Last Update Text (Matches Image)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOpen ? const Color(0xFFE8F8F0) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: isOpen ? Border.all(color: const Color(0xFFBBF7D0)) : Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOpen) ...[
                      // Green circle dot on the RIGHT in RTL
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'السوق مفتوح • يغلق 14:30',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'السوق مغلق',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateAndTime(_lastUpdateTime),
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          // 2. Left in RTL: Circular Refresh Button (Matches Image)
          InkWell(
            onTap: () {
              setState(() {
                _lastUpdateTime = DateTime.now();
              });
              _loadStatus();
              widget.onRefresh?.call();
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Color(0xFFC1121F),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
