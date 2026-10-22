import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_keys.dart';

typedef LiveQuoteUpdate = LivePriceUpdate;

class LivePriceUpdate {
  final String symbol;
  final double price;
  final double? previousClose;
  final double? change;
  final double? changePercent;
  final double? bid;
  final double? ask;
  final int? sourceUpdate;
  final bool stale;
  final bool snapshot;
  final DateTime receivedAt;

  const LivePriceUpdate({
    required this.symbol,
    required this.price,
    this.previousClose,
    this.change,
    this.changePercent,
    this.bid,
    this.ask,
    this.sourceUpdate,
    this.stale = false,
    this.snapshot = false,
    required this.receivedAt,
  });

  factory LivePriceUpdate.fromJson(Map<String, dynamic> json) {
    return LivePriceUpdate(
      symbol: (json['symbol'] ?? '').toString().trim(),
      price: _parseDouble(json['price']),
      previousClose: json['previousClose'] != null
          ? _parseDouble(json['previousClose'])
          : null,
      change: json['change'] != null ? _parseDouble(json['change']) : null,
      changePercent: json['changePercent'] != null
          ? _parseDouble(json['changePercent'])
          : null,
      bid: json['bid'] != null ? _parseDouble(json['bid']) : null,
      ask: json['ask'] != null ? _parseDouble(json['ask']) : null,
      sourceUpdate: json['sourceUpdate'] is num
          ? (json['sourceUpdate'] as num).toInt()
          : null,
      stale: json['stale'] == true,
      snapshot: json['snapshot'] == true,
      receivedAt: DateTime.now(),
    );
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^\d\.-]'), '');
      return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }

  bool get hasSpread => bid != null && ask != null && bid! > 0 && ask! > 0;
  double? get spread => hasSpread ? (ask! - bid!) : null;
  double? get spreadPercent =>
      hasSpread && bid! > 0 ? ((ask! - bid!) / bid!) * 100.0 : null;
}

class LiveSocketService {
  LiveSocketService._();
  static final LiveSocketService instance = LiveSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isAuthenticated = false;
  int _reconnectAttempts = 0;

  final Set<String> _subscribedSymbols = <String>{};
  final Map<String, LivePriceUpdate> _latestPrices = <String, LivePriceUpdate>{};
  final StreamController<LivePriceUpdate> _priceStreamController =
      StreamController<LivePriceUpdate>.broadcast();

  final List<void Function(LivePriceUpdate)> _priceAlertListeners = [];

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  Stream<LivePriceUpdate> get priceStream => _priceStreamController.stream;

  Stream<LivePriceUpdate> streamFor(String symbol) {
    final norm = _normalize(symbol);
    final clean = _cleanSymbol(symbol);
    return _priceStreamController.stream.where((u) {
      final uNorm = _normalize(u.symbol);
      final uClean = _cleanSymbol(u.symbol);
      return uNorm == norm || uClean == clean;
    });
  }

  LivePriceUpdate? getLatestPrice(String symbol) {
    final norm = _normalize(symbol);
    final clean = _cleanSymbol(symbol);
    return _latestPrices[norm] ?? _latestPrices[clean];
  }

  void addPriceAlertListener(void Function(LivePriceUpdate) listener) {
    _priceAlertListeners.add(listener);
  }

  void removePriceAlertListener(void Function(LivePriceUpdate) listener) {
    _priceAlertListeners.remove(listener);
  }

  void init() {
    connect();
  }

  void connect() {
    if (_isConnected) return;
    _cancelTimers();

    const url = ApiKeys.liveSocketUrl;
    try {
      final uri = Uri.parse(url);
      _channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 30),
      );
      _isConnected = true;

      _subscription = _channel?.stream.listen(
        _onMessageReceived,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _authenticate();
    } catch (e) {
      if (kDebugMode) {
        print('LiveSocket connection failed: $e');
      }
      _scheduleReconnect();
    }
  }

  void _authenticate() {
    if (_channel == null) return;
    final authMsg = jsonEncode({
      'type': 'auth',
      'key': ApiKeys.liveSocketKey,
    });
    _channel?.sink.add(authMsg);
  }

  void _onMessageReceived(dynamic message) {
    try {
      final decoded = jsonDecode(message.toString());
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type']?.toString();
      if (type == 'authenticated') {
        _isAuthenticated = true;
        _reconnectAttempts = 0;
        _startPingTimer();
        _resubscribeAll();
      } else if (type == 'price') {
        final update = LivePriceUpdate.fromJson(decoded);
        if (update.symbol.isNotEmpty) {
          _latestPrices[_normalize(update.symbol)] = update;
          _latestPrices[_cleanSymbol(update.symbol)] = update;
          _priceStreamController.add(update);

          for (final listener in _priceAlertListeners) {
            try {
              listener(update);
            } catch (_) {}
          }
        }
      } else if (type == 'pong') {
        // Pong received, keepalive ok
      }
    } catch (e) {
      if (kDebugMode) {
        print('LiveSocket parse error: $e');
      }
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_channel != null && _isAuthenticated) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _resubscribeAll() {
    if (!_isAuthenticated || _subscribedSymbols.isEmpty) return;
    final items = _subscribedSymbols
        .map((sym) => {'symbol': sym, 'timeframe': '60'})
        .toList();
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'subscribe_batch',
        'items': items,
      }));
    } catch (_) {}
  }

  void subscribe(String symbol) {
    final norm = _normalize(symbol);
    if (norm.isEmpty) return;

    final wasEmpty = !_subscribedSymbols.contains(norm);
    _subscribedSymbols.add(norm);

    if (_isAuthenticated && wasEmpty) {
      try {
        _channel?.sink.add(jsonEncode({
          'type': 'subscribe_batch',
          'items': [
            {'symbol': norm, 'timeframe': '60'}
          ]
        }));
      } catch (_) {}
    }
  }

  void subscribeBatch(List<String> symbols) {
    final toAdd = <String>[];
    for (final s in symbols) {
      final norm = _normalize(s);
      if (norm.isNotEmpty && !_subscribedSymbols.contains(norm)) {
        _subscribedSymbols.add(norm);
        toAdd.add(norm);
      }
    }

    if (_isAuthenticated && toAdd.isNotEmpty) {
      try {
        final items = toAdd
            .map((sym) => {'symbol': sym, 'timeframe': '60'})
            .toList();
        _channel?.sink.add(jsonEncode({
          'type': 'subscribe_batch',
          'items': items,
        }));
      } catch (_) {}
    }
  }

  void unsubscribe(String symbol) {
    final norm = _normalize(symbol);
    if (norm.isEmpty) return;
    if (_subscribedSymbols.remove(norm) && _isAuthenticated) {
      try {
        _channel?.sink.add(jsonEncode({
          'type': 'unsubscribe_batch',
          'items': [
            {'symbol': norm, 'timeframe': '60'}
          ]
        }));
      } catch (_) {}
    }
  }

  void unsubscribeBatch(List<String> symbols) {
    final toRemove = <String>[];
    for (final s in symbols) {
      final norm = _normalize(s);
      if (_subscribedSymbols.remove(norm)) {
        toRemove.add(norm);
      }
    }

    if (_isAuthenticated && toRemove.isNotEmpty) {
      try {
        final items = toRemove
            .map((sym) => {'symbol': sym, 'timeframe': '60'})
            .toList();
        _channel?.sink.add(jsonEncode({
          'type': 'unsubscribe_batch',
          'items': items,
        }));
      } catch (_) {}
    }
  }

  void _onError(dynamic error) {
    if (kDebugMode) {
      print('LiveSocket error: $error');
    }
    _handleDisconnect();
  }

  void _onDone() {
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _isConnected = false;
    _isAuthenticated = false;
    _cancelTimers();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    _scheduleReconnect();
  }

  void _cancelTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 15);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  String _normalize(String s) {
    var str = s.trim().toUpperCase();
    if (str.isEmpty) return '';
    if (!str.contains(':')) {
      str = 'EGX:$str';
    }
    return str;
  }

  String _cleanSymbol(String s) {
    var str = s.trim().toUpperCase();
    if (str.contains(':')) {
      str = str.split(':').last;
    }
    return str;
  }

  void dispose() {
    _cancelTimers();
    _subscription?.cancel();
    _channel?.sink.close();
    _priceStreamController.close();
  }
}
