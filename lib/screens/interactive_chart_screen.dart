import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/models/stock_model.dart';
import '../core/utils/constants.dart';

class InteractiveChartScreen extends StatefulWidget {
  final StockModel stock;

  const InteractiveChartScreen({super.key, required this.stock});

  @override
  State<InteractiveChartScreen> createState() => _InteractiveChartScreenState();
}

class _InteractiveChartScreenState extends State<InteractiveChartScreen> {
  WebViewController? _webViewController;
  bool _isLoading = true;
  String _selectedPeriod = '1D';

  final List<Map<String, String>> _periods = [
    {'label': '1د', 'value': '1m'},
    {'label': '5د', 'value': '5m'},
    {'label': '15د', 'value': '15m'},
    {'label': '1س', 'value': '1h'},
    {'label': 'يوم', 'value': '1D'},
    {'label': 'أسبوع', 'value': '1W'},
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (kDebugMode) {
              debugPrint('WebView error: ${error.description}');
            }
          },
        ),
      );

    _loadChartHtml(controller, _selectedPeriod);
    _webViewController = controller;
  }

  String _cleanSymbol() {
    return widget.stock.symbol.replaceAll('EGX:', '').trim();
  }

  String _tradingViewInterval(String period) {
    switch (period.toLowerCase()) {
      case '1m':
        return '1';
      case '5m':
        return '5';
      case '15m':
        return '15';
      case '30m':
        return '30';
      case '1h':
        return '60';
      case '4h':
        return '240';
      case '1d':
        return 'D';
      case '1w':
        return 'W';
      case '1month':
        return 'M';
      default:
        return 'D';
    }
  }

  void _loadChartHtml(WebViewController controller, String period) {
    final clean = _cleanSymbol();
    final tvInterval = _tradingViewInterval(period);

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #0b111e;
      overflow: hidden;
    }
    #tv_chart_container {
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div id="tv_chart_container"></div>
  <script type="text/javascript" src="https://s3.tradingview.com/tv.js"></script>
  <script type="text/javascript">
    new TradingView.widget({
      "autosize": true,
      "symbol": "EGX:$clean",
      "interval": "$tvInterval",
      "timezone": "Africa/Cairo",
      "theme": "dark",
      "style": "1",
      "locale": "ar_AE",
      "toolbar_bg": "#0b111e",
      "enable_publishing": false,
      "allow_symbol_change": true,
      "container_id": "tv_chart_container"
    });
  </script>
</body>
</html>
''';

    controller.loadHtmlString(htmlContent);
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    if (_webViewController != null) {
      _loadChartHtml(_webViewController!, period);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clean = _cleanSymbol();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.stock.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.stock.symbol} • الشارت التفاعلي',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded, size: 22),
            tooltip: 'فتح في TradingView',
            onPressed: () async {
              final url = Uri.parse(
                'https://ar.tradingview.com/symbols/EGX-$clean/',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Timeframe Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _periods.map((p) {
                final isSelected = _selectedPeriod == p['value'];
                return InkWell(
                  onTap: () => _onPeriodChanged(p['value']!),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // WebView Container
          Expanded(
            child: Stack(
              children: [
                if (_webViewController != null)
                  WebViewWidget(controller: _webViewController!),
                if (_isLoading)
                  Center(
                    child: CircularProgressIndicator(color: AppColors.primaryBlue),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
