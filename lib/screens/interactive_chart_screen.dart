import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/api/api_keys.dart';
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

  void _loadChartHtml(WebViewController controller, String period) {
    final apiKey = ApiKeys.fcsApiKey;
    final symbol = widget.stock.symbol;

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/fcsapi/chart-js@latest/src/fcsapi-chart.css">
  <style>
    * { box-sizing: border-box; }
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      background-color: #0b111e;
      overflow: hidden;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    #fcs_chartparent {
      width: 100%;
      height: 100vh;
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
    }
    #fcs_chart {
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div id="fcs_chartparent">
    <div id="fcs_chart"></div>
  </div>
  <script src="https://cdn.jsdelivr.net/gh/fcsapi/chart-js@latest/src/fcsapi-chart.js"></script>
  <script>
    window.addEventListener("DOMContentLoaded", function() {
      try {
        new FCSAPIChart({
          container: document.getElementById('fcs_chart'),
          parentid: 'fcs_chartparent',
          accessKey: '$apiKey',
          symbol: '$symbol',
          period: '$period',
          length: 300,
          theme: 'dark'
        });
      } catch (err) {
        console.error("FCS Chart error:", err);
      }
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
            tooltip: 'فتح في المتصفح',
            onPressed: () async {
              final url = Uri.parse(
                'https://fcsapi.com/widgets/stock-chart?symbol=${widget.stock.symbol}',
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
