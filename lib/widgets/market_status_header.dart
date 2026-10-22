import 'dart:async';
import 'package:flutter/material.dart';

import '../core/models/market_status_model.dart';
import '../core/services/stock_service.dart';
import '../core/utils/constants.dart';

class MarketStatusHeader extends StatefulWidget {
  const MarketStatusHeader({super.key});

  @override
  State<MarketStatusHeader> createState() => _MarketStatusHeaderState();
}

class _MarketStatusHeaderState extends State<MarketStatusHeader> {
  MarketStatusModel? _status;
  bool _isLoading = true;
  Timer? _countdownTimer;
  String _countdownText = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final res = await StockService.getMarketStatus();
      if (mounted) {
        setState(() {
          _status = res;
          _isLoading = false;
        });
        _updateCountdown();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateCountdown() {
    if (_status == null) return;

    final targetTime = _status!.isOpen
        ? _status!.nextCloseTime
        : _status!.nextOpenTime;

    if (targetTime == null) {
      if (mounted && _countdownText.isNotEmpty) {
        setState(() => _countdownText = '');
      }
      return;
    }

    final now = DateTime.now();
    final diff = targetTime.difference(now);
    if (diff.isNegative) {
      if (mounted && _countdownText.isNotEmpty) {
        setState(() => _countdownText = '');
      }
      return;
    }

    final hours = diff.inHours.toString().padLeft(2, '0');
    final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');

    final prefix = _status!.isOpen ? 'يغلق بعد' : 'يفتح بعد';
    final text = '$prefix $hours:$minutes:$seconds';

    if (mounted && _countdownText != text) {
      setState(() => _countdownText = text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }

    final status = _status ?? MarketStatusModel.fallback();
    final statusColor = status.isOpen ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Pulse Indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status & Session (Flexible to prevent any overflow)
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Text(
                  status.localizedStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '• ${status.startTime ?? "10:00"} - ${status.endTime ?? "14:30"}',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Countdown if available
          if (_countdownText.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _countdownText,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
