import 'dart:async';
import 'package:flutter/material.dart';

import '../core/models/currency_conversion_model.dart';
import '../core/services/stock_service.dart';
import '../core/utils/formatters.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  static const List<Map<String, String>> _popularCurrencies = [
    {'code': 'USD', 'name': 'الدولار الأمريكي', 'country': 'us', 'symbol': r'$'},
    {'code': 'EGP', 'name': 'الجنيه المصري', 'country': 'eg', 'symbol': 'ج.م'},
    {'code': 'SAR', 'name': 'الريال السعودي', 'country': 'sa', 'symbol': 'ر.س'},
    {'code': 'AED', 'name': 'الدرهم الإماراتي', 'country': 'ae', 'symbol': 'د.إ'},
    {'code': 'EUR', 'name': 'اليورو الأوروبي', 'country': 'eu', 'symbol': '€'},
    {'code': 'GBP', 'name': 'الجنيه الإسترليني', 'country': 'gb', 'symbol': '£'},
    {'code': 'KWD', 'name': 'الدينار الكويتي', 'country': 'kw', 'symbol': 'د.ك'},
    {'code': 'QAR', 'name': 'الريال القطري', 'country': 'qa', 'symbol': 'ر.ق'},
    {'code': 'BHD', 'name': 'الدينار البحريني', 'country': 'bh', 'symbol': 'د.ب'},
    {'code': 'OMR', 'name': 'الريال العماني', 'country': 'om', 'symbol': 'ر.ع'},
    {'code': 'JOD', 'name': 'الدينار الأردني', 'country': 'jo', 'symbol': 'د.أ'},
    {'code': 'TRY', 'name': 'الليرة التركية', 'country': 'tr', 'symbol': '₺'},
    {'code': 'CAD', 'name': 'الدولار الكندي', 'country': 'ca', 'symbol': r'C$'},
    {'code': 'CHF', 'name': 'الفرنك السويسري', 'country': 'ch', 'symbol': 'CHF'},
    {'code': 'JPY', 'name': 'الين الياباني', 'country': 'jp', 'symbol': '¥'},
    {'code': 'CNY', 'name': 'اليوان الصيني', 'country': 'cn', 'symbol': '¥'},
  ];

  String _fromCurrency = 'USD';
  String _toCurrency = 'EGP';
  final TextEditingController _amountController = TextEditingController(text: '100');

  CurrencyConversionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;
  DateTime _lastUpdateTime = DateTime.now();

  double _lastKnownRate = 48.50;

  @override
  void initState() {
    super.initState();
    _performConversion();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performConversion();
    });
  }

  void _swapCurrencies() {
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
      if (_lastKnownRate > 0) {
        _lastKnownRate = 1.0 / _lastKnownRate;
      }
    });
    _performConversion();
  }

  Future<void> _performConversion() async {
    final rawAmount = double.tryParse(_amountController.text.trim());
    if (rawAmount == null || rawAmount <= 0) {
      if (mounted) {
        setState(() {
          _result = null;
          _errorMessage = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await StockService.convertCurrency(
        from: _fromCurrency,
        to: _toCurrency,
        amount: rawAmount,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
          _lastUpdateTime = DateTime.now();
          if (res.rate > 0) {
            _lastKnownRate = res.rate;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحديث سعر الصرف';
        });
      }
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _getCurrencyName(String code) {
    final found = _popularCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'name': code},
    );
    return found['name'] ?? code;
  }

  String _getCountryCode(String code) {
    final found = _popularCurrencies.firstWhere(
      (c) => c['code'] == code,
      orElse: () => {'country': 'eg'},
    );
    return found['country'] ?? 'eg';
  }

  Widget _buildFlagCircle(String currencyCode, {double size = 42}) {
    final country = _getCountryCode(currencyCode);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        'https://flagcdn.com/w80/$country.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            currencyCode.length >= 2 ? currencyCode.substring(0, 2) : currencyCode,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Color(0xFFC1121F),
            ),
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker({required bool isFrom}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _popularCurrencies.where((c) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return (c['code'] ?? '').toLowerCase().contains(q) ||
                  (c['name'] ?? '').toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isFrom ? 'اختر عملة التحويل (من)' : 'اختر عملة الاستلام (إلى)',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search field
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ابحث باسم العملة أو الرمز...',
                          hintTextDirection: TextDirection.rtl,
                          hintStyle: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                          suffixIcon: Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        ),
                        onChanged: (v) => setModalState(() => searchQuery = v),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Currency list
                    Expanded(
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (context, idx) {
                          final c = filtered[idx];
                          final code = c['code']!;
                          final name = c['name']!;
                          final isSelected = isFrom
                              ? _fromCurrency == code
                              : _toCurrency == code;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                if (isFrom) {
                                  _fromCurrency = code;
                                } else {
                                  _toCurrency = code;
                                }
                              });
                              _performConversion();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  _buildFlagCircle(code, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          code,
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFFC1121F),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final bool hasAmount = rawAmount > 0;
    final double currentRate = _result?.rate ?? _lastKnownRate;
    final double inverseRate = currentRate > 0 ? (1.0 / currentRate) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_forward_ios,
            size: 20,
            color: Color(0xFF1E293B),
          ),
        ),
        title: const Text(
          'محول العملات',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // 1. AMOUNT CARD (المبلغ)
            // ==========================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Label "المبلغ" (Right in RTL)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'المبلغ',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Red bordered input container
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFDC2626),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // Input Field (Right in RTL)
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'أدخل المبلغ',
                              hintTextDirection: TextDirection.rtl,
                              hintStyle: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14.5,
                                color: Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: _onAmountChanged,
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Currency code badge (Left in RTL)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _fromCurrency,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ==========================================
            // 2. FROM / TO CURRENCY SELECTOR CARD
            // ==========================================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Column(
                    children: [
                      // Top Row: من
                      InkWell(
                        onTap: () => _showCurrencyPicker(isFrom: true),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              _buildFlagCircle(_fromCurrency, size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'من',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_fromCurrency • ${_getCurrencyName(_fromCurrency)}',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF64748B),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Divider Line
                      const Padding(
                        padding: EdgeInsets.only(left: 60, right: 16),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFF1F5F9),
                        ),
                      ),

                      // Bottom Row: إلى
                      InkWell(
                        onTap: () => _showCurrencyPicker(isFrom: false),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              _buildFlagCircle(_toCurrency, size: 42),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'إلى',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_toCurrency • ${_getCurrencyName(_toCurrency)}',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF64748B),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Floating Circular Red Swap Button on Left
                  Positioned(
                    left: 14,
                    child: InkWell(
                      onTap: _swapCurrencies,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.swap_vert_rounded,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ==========================================
            // 3. RESULT CARD / ERROR CARD
            // ==========================================
            if (_errorMessage != null) ...[
              // --- Error Card (Image 1) ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Exclamation Circle Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 28,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'تعذر تحديث سعر الصرف',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'تأكد من اتصالك بالإنترنت ثم حاول مرة أخرى.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Red Try Again Button
                    InkWell(
                      onTap: _performConversion,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC1121F),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'إعادة المحاولة',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'آخر سعر معروف: 1 $_fromCurrency = ${currentRate.toStringAsFixed(2)} $_toCurrency',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // --- Result / Empty Card (Image 2 & Image 4) ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Row: Title + Refresh Capsule
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        // Right: Title (e.g. 100 دولار أمريكي = or النتيجة)
                        Text(
                          hasAmount
                              ? '${_amountController.text} ${_getCurrencyName(_fromCurrency)} ='
                              : 'النتيجة',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),

                        // Left: Refresh capsule pill
                        InkWell(
                          onTap: _performConversion,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'تحديث • ${_formatTime(_lastUpdateTime)}',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.refresh_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Middle Section
                    if (_isLoading) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFC1121F),
                          ),
                        ),
                      ),
                    ] else if (!hasAmount) ...[
                      // Empty prompt
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'أدخل المبلغ لعرض النتيجة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Converted value row (Image 4)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              Formatters.formatNumber(
                                _result != null
                                    ? _result!.total
                                    : (rawAmount * currentRate),
                              ),
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getCurrencyName(_toCurrency),
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    // Bottom Row: 1 USD = 48.50 EGP (Right) and 1 EGP = 0.0206 USD (Left)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text(
                          '1 $_fromCurrency = ${currentRate.toStringAsFixed(2)} $_toCurrency',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          '1 $_toCurrency = ${inverseRate.toStringAsFixed(4)} $_fromCurrency',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ==========================================
            // 4. FOOTER DISCLAIMER
            // ==========================================
            const Center(
              child: Text(
                'الأسعار استرشادية وقد تختلف عن أسعار البنوك وشركات الصرافة.',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
