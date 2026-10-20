import 'dart:async';
import 'package:flutter/material.dart';

import '../core/models/currency_conversion_model.dart';
import '../core/services/stock_service.dart';
import '../core/utils/constants.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  static const List<Map<String, String>> _popularCurrencies = [
    {'code': 'EGP', 'name': 'الجنيه المصري', 'flag': '🇪🇬'},
    {'code': 'USD', 'name': 'الدولار الأمريكي', 'flag': '🇺🇸'},
    {'code': 'SAR', 'name': 'الريال السعودي', 'flag': '🇸🇦'},
    {'code': 'AED', 'name': 'الدرهم الإماراتي', 'flag': '🇦🇪'},
    {'code': 'EUR', 'name': 'اليورو الأوروبي', 'flag': '🇪🇺'},
    {'code': 'GBP', 'name': 'الجنيه الإسترليني', 'flag': '🇬🇧'},
    {'code': 'KWD', 'name': 'الدينار الكويتي', 'flag': '🇰🇼'},
    {'code': 'QAR', 'name': 'الريال القطري', 'flag': '🇶🇦'},
    {'code': 'BHD', 'name': 'الدينار البحريني', 'flag': '🇧🇭'},
    {'code': 'OMR', 'name': 'الريال العماني', 'flag': '🇴🇲'},
    {'code': 'JOD', 'name': 'الدينار الأردني', 'flag': '🇯🇴'},
    {'code': 'TRY', 'name': 'الليرة التركية', 'flag': '🇹🇷'},
    {'code': 'CAD', 'name': 'الدولار الكندي', 'flag': '🇨🇦'},
    {'code': 'CHF', 'name': 'الفرنك السويسري', 'flag': '🇨🇭'},
    {'code': 'JPY', 'name': 'الين الياباني', 'flag': '🇯🇵'},
    {'code': 'CNY', 'name': 'اليوان الصيني', 'flag': '🇨🇳'},
  ];

  String _fromCurrency = 'USD';
  String _toCurrency = 'EGP';
  final TextEditingController _amountController = TextEditingController(text: '100');

  CurrencyConversionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;

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
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performConversion();
    });
  }

  void _swapCurrencies() {
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
    });
    _performConversion();
  }

  Future<void> _performConversion() async {
    final rawAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (rawAmount <= 0) {
      setState(() {
        _result = null;
        _errorMessage = null;
      });
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحديث سعر الصرف حالياً، يرجى المحاولة بعد قليل.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('محول العملات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            // Amount Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المبلغ المراد تحويله',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'أدخل المبلغ',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.4)),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: _onAmountChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Currency Selectors & Swap
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildCurrencySelector(
                      label: 'من العملة',
                      selected: _fromCurrency,
                      onChanged: (val) {
                        if (val != null && val != _fromCurrency) {
                          setState(() => _fromCurrency = val);
                          _performConversion();
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                      onPressed: _swapCurrencies,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColors.primaryBlue,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildCurrencySelector(
                      label: 'إلى العملة',
                      selected: _toCurrency,
                      onChanged: (val) {
                        if (val != null && val != _toCurrency) {
                          setState(() => _toCurrency = val);
                          _performConversion();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Conversion Result Box
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              )
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      AppColors.primaryBlue.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_amountController.text} $_fromCurrency يساوي',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_result!.total.toStringAsFixed(2)} $_toCurrency',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.black.withOpacity(0.06)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '1 $_fromCurrency = ${_result!.rate.toStringAsFixed(4)} $_toCurrency',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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

  Widget _buildCurrencySelector({
    required String label,
    required String selected,
    required ValueChanged<String?> onChanged,
  }) {
    final currentItem = _popularCurrencies.firstWhere(
      (c) => c['code'] == selected,
      orElse: () => {'code': selected, 'name': selected, 'flag': '🌐'},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
              items: _popularCurrencies.map((item) {
                return DropdownMenuItem<String>(
                  value: item['code'],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item['flag'] ?? '', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        item['code']!,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currentItem['name'] ?? '',
          style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
