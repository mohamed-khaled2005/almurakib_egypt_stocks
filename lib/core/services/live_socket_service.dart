import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_keys.dart';

typedef LiveQuoteUpdate = LivePriceUpdate;

/// Live price update payload adhering to Almurakib LiveSocket v2.0 protocol
class LivePriceUpdate {
  final String symbol;
  final String? timeframe;
  final double price;
  final double? bid;
  final double? ask;
  final double? open;
  final double? high;
  final double? low;
  final double? volume;
  final double? change;
  final double? changePercent;
  final double? previousClose;
  final String source; // 'websocket' or 'rest'
  final bool snapshot;
  final bool stale;
  final String freshness; // 'fresh', 'stale', etc.
  final int? sourceUpdate; // Unix seconds
  final DateTime receivedAt;

  const LivePriceUpdate({
    required this.symbol,
    this.timeframe = '60',
    required this.price,
    this.bid,
    this.ask,
    this.open,
    this.high,
    this.low,
    this.volume,
    this.change,
    this.changePercent,
    this.previousClose,
    this.source = 'websocket',
    this.snapshot = false,
    this.stale = false,
    this.freshness = 'fresh',
    this.sourceUpdate,
    required this.receivedAt,
  });

  factory LivePriceUpdate.fromJson(Map<String, dynamic> json) {
    final sym = (json['symbol'] ?? json['s'] ?? '').toString().trim();
    final rawChangePercent = json['changePercent'] ?? json['cp'] ?? json['chp'];
    final rawChange = json['change'] ?? json['ch'];
    final rawPrevClose = json['previousClose'] ?? json['pc'];

    return LivePriceUpdate(
      symbol: sym,
      timeframe: json['timeframe']?.toString() ?? '60',
      price: _parseDouble(json['price'] ?? json['p'] ?? json['c']),
      bid: _parseNullableDouble(json['bid'] ?? json['b']),
      ask: _parseNullableDouble(json['ask'] ?? json['a']),
      open: _parseNullableDouble(json['open'] ?? json['o']),
      high: _parseNullableDouble(json['high'] ?? json['h']),
      low: _parseNullableDouble(json['low'] ?? json['l']),
      volume: _parseNullableDouble(json['volume'] ?? json['v']),
      change: _parseNullableDouble(rawChange),
      changePercent: _parseNullableDouble(rawChangePercent),
      previousClose: _parseNullableDouble(rawPrevClose),
      source: (json['source'] ?? 'websocket').toString(),
      snapshot: json['snapshot'] == true,
      stale: json['stale'] == true,
      freshness: (json['freshness'] ?? 'fresh').toString(),
      sourceUpdate: json['sourceUpdate'] is num
          ? (json['sourceUpdate'] as num).toInt()
          : null,
      receivedAt: json['receivedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch((json['receivedAt'] as num).toInt())
          : DateTime.now(),
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

  static double? _parseNullableDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^\d\.-]'), '');
      return double.tryParse(clean);
    }
    return null;
  }

  bool get hasSpread => bid != null && ask != null && bid! > 0 && ask! > 0;
  double? get spread => hasSpread ? (ask! - bid!) : null;
  double? get spreadPercent =>
      hasSpread && bid! > 0 ? (((ask! - bid!) / bid!) * 100.0) : null;
}

/// Almurakib LiveSocket v2.0 Client
///
/// Implements connection lifecycle, auth handshake, subscription batching,
/// exponential backoff reconnection, ping keepalives, and event streams.
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
  bool _stopped = false;

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
    _stopped = false;
    connect();
  }

  void connect() {
    if (_stopped || _isConnected) return;
    _cancelTimers();

    final url = ApiKeys.liveSocketUrl;
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
        print('LiveSocket connection error: $e');
      }
      _handleDisconnect();
    }
  }

  void _authenticate() {
    if (_channel == null) return;
    try {
      final authMsg = jsonEncode({
        'type': 'auth',
        'key': ApiKeys.liveSocketKey,
      });
      _channel?.sink.add(authMsg);
    } catch (_) {}
  }

  void _onMessageReceived(dynamic rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage.toString());
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type']?.toString();

      switch (type) {
        case 'authenticated':
          _isAuthenticated = true;
          _reconnectAttempts = 0;
          _startPingTimer();
          _resubscribeAll();
          break;

        case 'price':
          final update = LivePriceUpdate.fromJson(decoded);
          if (update.symbol.isNotEmpty) {
            final norm = _normalize(update.symbol);
            final clean = _cleanSymbol(update.symbol);

            _latestPrices[norm] = update;
            _latestPrices[clean] = update;
            _priceStreamController.add(update);

            for (final listener in _priceAlertListeners) {
              try {
                listener(update);
              } catch (_) {}
            }
          }
          break;

        case 'subscribed':
          // Confirmed subscription upstream
          break;

        case 'unsubscribed':
          // Confirmed unsubscription upstream
          break;

        case 'pong':
          // Keepalive OK
          break;

        case 'market_status':
          // Optional market status broadcast
          break;

        case 'quote_status':
          // Optional quote quality broadcast
          break;

        case 'error':
          if (kDebugMode) {
            print('LiveSocket server error: ${decoded['message']}');
          }
          break;

        default:
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('LiveSocket message parse error: $e');
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
          'type': 'subscribe',
          'symbol': norm,
          'timeframe': '60',
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
          'type': 'unsubscribe',
          'symbol': norm,
          'timeframe': '60',
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
      print('LiveSocket stream error: $error');
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
    try {
      _subscription?.cancel();
    } catch (_) {}
    _subscription = null;
    _channel = null;

    if (!_stopped) {
      _scheduleReconnect();
    }
  }

  void _cancelTimers() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Exponential backoff reconnect formula adhering to LiveSocket v2.0 Guide:
  /// delay = min(30000, 1000 * 2^min(attempts, 5)) + random(500)
  void _scheduleReconnect() {
    if (_stopped || (_reconnectTimer != null && _reconnectTimer!.isActive)) return;

    final expDelay = 1000 * (1 << math.min(_reconnectAttempts, 5));
    _reconnectAttempts++;
    final delayMs = math.min(30000, expDelay) + math.Random().nextInt(500);

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
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

  void stop() {
    _stopped = true;
    _cancelTimers();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _isConnected = false;
    _isAuthenticated = false;
  }

  void dispose() {
    stop();
    _priceStreamController.close();
  }
}
