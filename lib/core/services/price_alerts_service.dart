import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/push_notification_service.dart';
import 'live_socket_service.dart';

enum AlertDirection {
  above('أعلى من'),
  below('أدنى من');

  final String label;
  const AlertDirection(this.label);
}

class StockPriceAlert {
  final String id;
  final String symbol;
  final String stockName;
  final double targetPrice;
  final AlertDirection direction;
  final bool isActive;
  final bool isTriggered;
  final DateTime createdAt;
  final DateTime? triggeredAt;

  const StockPriceAlert({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.targetPrice,
    required this.direction,
    this.isActive = true,
    this.isTriggered = false,
    required this.createdAt,
    this.triggeredAt,
  });

  StockPriceAlert copyWith({
    bool? isActive,
    bool? isTriggered,
    DateTime? triggeredAt,
  }) {
    return StockPriceAlert(
      id: id,
      symbol: symbol,
      stockName: stockName,
      targetPrice: targetPrice,
      direction: direction,
      isActive: isActive ?? this.isActive,
      isTriggered: isTriggered ?? this.isTriggered,
      createdAt: createdAt,
      triggeredAt: triggeredAt ?? this.triggeredAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'stockName': stockName,
      'targetPrice': targetPrice,
      'direction': direction.name,
      'isActive': isActive,
      'isTriggered': isTriggered,
      'createdAt': createdAt.toIso8601String(),
      'triggeredAt': triggeredAt?.toIso8601String(),
    };
  }

  factory StockPriceAlert.fromJson(Map<String, dynamic> json) {
    return StockPriceAlert(
      id: (json['id'] ?? '').toString(),
      symbol: (json['symbol'] ?? '').toString().trim().toUpperCase(),
      stockName: (json['stockName'] ?? '').toString(),
      targetPrice: (json['targetPrice'] is num)
          ? (json['targetPrice'] as num).toDouble()
          : double.tryParse(json['targetPrice'].toString()) ?? 0.0,
      direction: json['direction'] == 'below'
          ? AlertDirection.below
          : AlertDirection.above,
      isActive: json['isActive'] != false,
      isTriggered: json['isTriggered'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      triggeredAt: json['triggeredAt'] != null
          ? DateTime.tryParse(json['triggeredAt'].toString())
          : null,
    );
  }
}

class PriceAlertsService {
  PriceAlertsService._();
  static final PriceAlertsService instance = PriceAlertsService._();

  static const String _storageKey = 'stock_price_alerts_v1';
  final ValueNotifier<List<StockPriceAlert>> alertsNotifier =
      ValueNotifier<List<StockPriceAlert>>(<StockPriceAlert>[]);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadAlerts();
    LiveSocketService.instance.addPriceAlertListener(_onLivePriceReceived);
  }

  Future<void> _loadAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? <String>[];
      final alerts = <StockPriceAlert>[];
      for (final item in rawList) {
        try {
          final decoded = jsonDecode(item);
          if (decoded is Map<String, dynamic>) {
            alerts.add(StockPriceAlert.fromJson(decoded));
          }
        } catch (_) {}
      }
      alertsNotifier.value = alerts;

      // Ensure all symbols for active alerts are subscribed
      final activeSymbols = alerts
          .where((a) => a.isActive && !a.isTriggered)
          .map((a) => a.symbol)
          .toSet()
          .toList();
      if (activeSymbols.isNotEmpty) {
        LiveSocketService.instance.subscribeBatch(activeSymbols);
      }
    } catch (_) {}
  }

  Future<void> _saveAlerts(List<StockPriceAlert> alerts) async {
    alertsNotifier.value = alerts;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = alerts.map((a) => jsonEncode(a.toJson())).toList();
      await prefs.setStringList(_storageKey, stringList);
    } catch (_) {}
  }

  List<StockPriceAlert> get alerts => alertsNotifier.value;

  List<StockPriceAlert> alertsForStock(String symbol) {
    final norm = symbol.trim().toUpperCase();
    return alertsNotifier.value.where((a) => a.symbol == norm).toList();
  }

  Future<void> addAlert({
    required String symbol,
    required String stockName,
    required double targetPrice,
    required AlertDirection direction,
  }) async {
    final cleanSymbol = symbol.trim().toUpperCase();
    final id = 'alt_${DateTime.now().millisecondsSinceEpoch}_${cleanSymbol.replaceAll(':', '_')}';
    final newAlert = StockPriceAlert(
      id: id,
      symbol: cleanSymbol,
      stockName: stockName,
      targetPrice: targetPrice,
      direction: direction,
      createdAt: DateTime.now(),
    );

    final current = List<StockPriceAlert>.from(alertsNotifier.value);
    current.insert(0, newAlert);
    await _saveAlerts(current);

    LiveSocketService.instance.subscribe(cleanSymbol);
  }

  Future<void> removeAlert(String id) async {
    final current = List<StockPriceAlert>.from(alertsNotifier.value);
    final removedIndex = current.indexWhere((a) => a.id == id);
    if (removedIndex >= 0) {
      final removed = current.removeAt(removedIndex);
      await _saveAlerts(current);

      final hasOther = current.any((a) => a.symbol == removed.symbol && a.isActive && !a.isTriggered);
      if (!hasOther) {
        LiveSocketService.instance.unsubscribe(removed.symbol);
      }
    }
  }

  Future<void> toggleAlert(String id) async {
    final current = List<StockPriceAlert>.from(alertsNotifier.value);
    final index = current.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final alert = current[index];
      final updated = alert.copyWith(isActive: !alert.isActive);
      current[index] = updated;
      await _saveAlerts(current);

      if (updated.isActive && !updated.isTriggered) {
        LiveSocketService.instance.subscribe(updated.symbol);
      }
    }
  }

  Future<void> clearTriggered() async {
    final current = alertsNotifier.value.where((a) => !a.isTriggered).toList();
    await _saveAlerts(current);
  }

  void _onLivePriceReceived(LivePriceUpdate update) {
    final current = List<StockPriceAlert>.from(alertsNotifier.value);
    var modified = false;

    for (var i = 0; i < current.length; i++) {
      final alert = current[i];
      if (!alert.isActive || alert.isTriggered) continue;
      if (alert.symbol != update.symbol) continue;

      var shouldTrigger = false;
      if (alert.direction == AlertDirection.above && update.price >= alert.targetPrice) {
        shouldTrigger = true;
      } else if (alert.direction == AlertDirection.below && update.price <= alert.targetPrice) {
        shouldTrigger = true;
      }

      if (shouldTrigger) {
        current[i] = alert.copyWith(
          isTriggered: true,
          triggeredAt: DateTime.now(),
        );
        modified = true;

        final directionText = alert.direction == AlertDirection.above ? 'تجاوز' : 'انخفض دون';
        PushNotificationService.instance.showLocalAlert(
          title: '🔔 تنبيه وصول السعر (${alert.stockName})',
          body: 'وصل سهم ${alert.stockName} إلى ${update.price} ج.م ($directionText السعر المستهدف ${alert.targetPrice} ج.م)',
          id: alert.id.hashCode,
        );
      }
    }

    if (modified) {
      _saveAlerts(current);
    }
  }
}
