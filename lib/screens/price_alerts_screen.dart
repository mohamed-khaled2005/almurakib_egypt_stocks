import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/services/price_alerts_service.dart';
import '../core/services/stock_service.dart';
import '../widgets/chevron_right_icon.dart';
import '../widgets/stock_logo_widget.dart';

class PriceAlertsScreen extends StatefulWidget {
  final StockModel? preselectedStock;

  const PriceAlertsScreen({super.key, this.preselectedStock});

  @override
  State<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends State<PriceAlertsScreen> {
  List<StockModel> _allStocks = [];
  bool _loadingStocks = false;

  @override
  void initState() {
    super.initState();
    _loadStocks();
    if (widget.preselectedStock != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCreateAlert(preselected: widget.preselectedStock);
      });
    }
  }

  Future<void> _loadStocks() async {
    setState(() => _loadingStocks = true);
    try {
      final list = await StockService.getStocksList();
      if (mounted) {
        setState(() {
          _allStocks = list;
          _loadingStocks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStocks = false);
    }
  }

  StockModel? _findStock(String symbol) {
    final clean = symbol.trim().toUpperCase();
    for (final s in _allStocks) {
      if (s.symbol.toUpperCase() == clean ||
          s.id.toUpperCase() == clean ||
          s.symbol.toUpperCase().endsWith(':$clean') ||
          clean.endsWith(':${s.symbol.toUpperCase()}')) {
        return s;
      }
    }
    return null;
  }

  void _openCreateAlert({StockModel? preselected}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EditOrAddAlertScreen(
          preselectedStock: preselected,
          allStocks: _allStocks,
        ),
      ),
    );
  }

  void _openEditAlert(StockPriceAlert alert) {
    final stock = _findStock(alert.symbol);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => EditOrAddAlertScreen(
          alert: alert,
          preselectedStock: stock,
          allStocks: _allStocks,
        ),
      ),
    );
  }

  // ==========================================
  // Image 1 & 3: Delete Confirmation Bottom Sheet
  // ==========================================
  void _showDeleteBottomSheet(StockPriceAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final dirText =
            alert.direction == AlertDirection.above ? 'أعلى من' : 'أقل من';
        final symbolOnly = alert.symbol.contains(':')
            ? alert.symbol.split(':').last
            : alert.symbol;
        final targetStr = alert.targetPrice.toStringAsFixed(2);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'حذف التنبيه؟',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  'سيتم حذف تنبيه ${alert.stockName} $symbolOnly ($dirText $targetStr) نهائياً.',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    color: Color(0xFF4B5563),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),

                // Red Button: حذف التنبيه
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await PriceAlertsService.instance.removeAlert(alert.id);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC1121F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'حذف التنبيه',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Outlined Button: إلغاء
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تنبيهات الأسعار',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        leading: IconButton(
          icon: const ChevronRightIcon(
            size: 18,
            color: Color(0xFF374151),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Circular Pink/Red '+' Button (Matches Image 4)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: InkWell(
                onTap: () => _openCreateAlert(),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEE),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFCA5A5), width: 1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add_rounded,
                      color: Color(0xFFC1121F),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loadingStocks
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFC1121F)),
            )
          : ValueListenableBuilder<List<StockPriceAlert>>(
              valueListenable: PriceAlertsService.instance.alertsNotifier,
              builder: (context, alerts, _) {
                // ==========================================
                // Empty State (Image 5)
                // ==========================================
                if (alerts.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 36,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.notifications_none_rounded,
                                  size: 34,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'لا توجد تنبيهات أسعار نشطة',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'يمكنك إنشاء تنبيه لأي سهم لتصلك إشعارات لحظية فور وصول السعر للهدف.',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 22),
                            InkWell(
                              onTap: () => _openCreateAlert(),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: double.infinity,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC1121F),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'إضافة تنبيه جديد',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // ==========================================
                // Active Alerts List (Image 4)
                // ==========================================
                return ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    ...alerts.map((alert) {
                      final stock = _findStock(alert.symbol);
                      final dirText = alert.direction == AlertDirection.above
                          ? 'أعلى من'
                          : 'أقل من';
                      final targetStr = alert.targetPrice.toStringAsFixed(2);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Top Row: Switch + Stock Name/Subtitle + Logo
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  // Stock Logo
                                  StockLogoWidget(
                                    stock: stock,
                                    symbol: alert.symbol,
                                    name: alert.stockName,
                                    size: 44,
                                    borderRadius: 10,
                                  ),

                                  const SizedBox(width: 12),

                                  // Stock Name & Target text
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          alert.stockName,
                                          maxLines: 2,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'عندما يصبح السعر $dirText $targetStr',
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Toggle Switch
                                  GestureDetector(
                                    onTap: () {
                                      PriceAlertsService.instance
                                          .toggleAlert(alert.id);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 48,
                                      height: 28,
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        color: alert.isActive
                                            ? const Color(0xFFC1121F)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                      alignment: alert.isActive
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            ),

                            // Bottom Actions Row: تعديل on right, حذف on left (Image 4)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                textDirection: TextDirection.rtl,
                                children: [
                                  // Edit Button
                                  InkWell(
                                    onTap: () => _openEditAlert(alert),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: Color(0xFF475569),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'تعديل',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Delete Button
                                  InkWell(
                                    onTap: () => _showDeleteBottomSheet(alert),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                          color: Color(0xFFC1121F),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'حذف التنبيه',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFC1121F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 14),

                    // Footer text (Image 4)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'يحذف التنبيه تلقائياً بعد وصول السعر لهدفك، وتجد النتيجة في الإشعارات.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
    );
  }
}

// ============================================================================
// Edit / Add Alert Screen (Image 2)
// ============================================================================
class EditOrAddAlertScreen extends StatefulWidget {
  final StockPriceAlert? alert;
  final StockModel? preselectedStock;
  final List<StockModel> allStocks;

  const EditOrAddAlertScreen({
    super.key,
    this.alert,
    this.preselectedStock,
    required this.allStocks,
  });

  @override
  State<EditOrAddAlertScreen> createState() => _EditOrAddAlertScreenState();
}

class _EditOrAddAlertScreenState extends State<EditOrAddAlertScreen> {
  late StockModel? _selectedStock;
  late AlertDirection _direction;
  late TextEditingController _priceController;

  late AlertDirection _initialDirection;
  late String _initialPrice;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final alert = widget.alert;
    if (alert != null) {
      _selectedStock = widget.preselectedStock ??
          _findStockInList(alert.symbol, widget.allStocks);
      _direction = alert.direction;
      _priceController = TextEditingController(
        text: alert.targetPrice.toStringAsFixed(2),
      );
    } else {
      _selectedStock = widget.preselectedStock ??
          (widget.allStocks.isNotEmpty ? widget.allStocks.first : null);
      _direction = AlertDirection.below;
      _priceController = TextEditingController(
        text: _selectedStock != null
            ? _selectedStock!.price.toStringAsFixed(2)
            : '',
      );
    }

    _initialDirection = _direction;
    _initialPrice = _priceController.text.trim();
    _priceController.addListener(() => setState(() {}));
  }

  static StockModel? _findStockInList(
      String symbol, List<StockModel> list) {
    final clean = symbol.trim().toUpperCase();
    for (final s in list) {
      if (s.symbol.toUpperCase() == clean ||
          s.id.toUpperCase() == clean ||
          s.symbol.toUpperCase().endsWith(':$clean') ||
          clean.endsWith(':${s.symbol.toUpperCase()}')) {
        return s;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (widget.alert == null) {
      return _priceController.text.trim().isNotEmpty &&
          (double.tryParse(_priceController.text.trim()) ?? 0) > 0;
    }
    return _direction != _initialDirection ||
        _priceController.text.trim() != _initialPrice;
  }

  // ==========================================
  // Image 1: Delete Bottom Sheet from Edit Screen
  // ==========================================
  void _showDeleteBottomSheet() {
    final alert = widget.alert;
    if (alert == null) return;

    final dirText =
        alert.direction == AlertDirection.above ? 'أعلى من' : 'أقل من';
    final symbolOnly = alert.symbol.contains(':')
        ? alert.symbol.split(':').last
        : alert.symbol;
    final targetStr = alert.targetPrice.toStringAsFixed(2);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'حذف التنبيه؟',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  'سيتم حذف تنبيه ${alert.stockName} $symbolOnly ($dirText $targetStr) نهائياً.',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    color: Color(0xFF4B5563),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),

                // Red Button: حذف التنبيه
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await PriceAlertsService.instance.removeAlert(alert.id);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC1121F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'حذف التنبيه',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Outlined Button: إلغاء
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStockPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = widget.allStocks.where((s) {
              if (query.trim().isEmpty) return true;
              final q = query.trim().toLowerCase();
              return s.name.toLowerCase().contains(q) ||
                  s.symbol.toLowerCase().contains(q) ||
                  s.displayName.toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (_, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'اختر السهم للتنبيه',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              const SizedBox(width: 12),
                              const Icon(Icons.search_rounded,
                                  size: 20, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (val) {
                                    setSheetState(() => query = val);
                                  },
                                  textDirection: TextDirection.rtl,
                                  decoration: const InputDecoration(
                                    hintText: 'ابحث باسم أو رمز السهم',
                                    hintStyle: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, i) {
                            final s = filtered[i];
                            return InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _selectedStock = s;
                                  if (widget.alert == null) {
                                    _priceController.text =
                                        s.price.toStringAsFixed(2);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    StockLogoWidget(
                                      stock: s,
                                      size: 40,
                                      borderRadius: 10,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.displayName,
                                            maxLines: 2,
                                            softWrap: true,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            s.symbol,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${s.price.toStringAsFixed(2)} ج.م',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF111827),
                                      ),
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
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى إدخال سعر مستهدف صحيح.',
            style: TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    if (widget.alert != null) {
      await PriceAlertsService.instance.updateAlert(
        id: widget.alert!.id,
        targetPrice: price,
        direction: _direction,
      );
    } else if (_selectedStock != null) {
      await PriceAlertsService.instance.addAlert(
        symbol: _selectedStock!.symbol,
        stockName: _selectedStock!.displayName,
        targetPrice: price,
        direction: _direction,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.alert != null;
    final stock = _selectedStock;
    final stockLabel = stock != null
        ? '${stock.displayName} ${stock.symbol.contains(':') ? stock.symbol.split(':').last : stock.symbol}'
        : (widget.alert != null ? widget.alert!.stockName : 'اختر السهم');
    final currentPriceStr =
        stock != null ? stock.price.toStringAsFixed(2) : '21.21';

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEdit ? 'تعديل التنبيه' : 'إنشاء تنبيه جديد',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        leading: IconButton(
          icon: const ChevronRightIcon(
            size: 18,
            color: Color(0xFF374151),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ==========================================
            // Section 1: السهم (Image 2)
            // ==========================================
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'السهم',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 8),

            InkWell(
              onTap: isEdit ? null : _showStockPicker,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    if (_selectedStock != null) ...[
                      StockLogoWidget(
                        stock: _selectedStock,
                        size: 36,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        stockLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle under stock (Image 2)
            Text(
              isEdit
                  ? 'السعر الحالي $currentPriceStr جنيه. لا يمكن تغيير السهم، احذف التنبيه وأنشئ غيره.'
                  : 'السعر الحالي $currentPriceStr جنيه.',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 22),

            // ==========================================
            // Section 2: متى أنبهك؟ (Image 2)
            // ==========================================
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'متى أنبهك؟',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              textDirection: TextDirection.rtl,
              children: [
                // Button: أعلي من
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _direction = AlertDirection.above;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _direction == AlertDirection.above
                            ? const Color(0xFFFEE2E2)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _direction == AlertDirection.above
                              ? const Color(0xFFF87171)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'أعلي من',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: _direction == AlertDirection.above
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: _direction == AlertDirection.above
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Button: أقل من (Selected in Image 2)
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _direction = AlertDirection.below;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _direction == AlertDirection.below
                            ? const Color(0xFFFEE2E2)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _direction == AlertDirection.below
                              ? const Color(0xFFF87171)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'أقل من',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          fontWeight: _direction == AlertDirection.below
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: _direction == AlertDirection.below
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ==========================================
            // Section 3: السعر المستهدف (جنيه) (Image 2)
            // ==========================================
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'السعر المستهدف (جنيه)',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: '0.00',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 20),

            // ==========================================
            // Section 4: حذف التنبيه (Image 2)
            // ==========================================
            if (isEdit) ...[
              InkWell(
                onTap: _showDeleteBottomSheet,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Color(0xFFC1121F),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'حذف التنبيه',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFC1121F),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ] else ...[
              const SizedBox(height: 16),
            ],

            // ==========================================
            // Section 5: زر حفظ التعديلات / إنشاء (Image 2)
            // ==========================================
            if (!_hasChanges)
              // Grey disabled button (Image 2)
              Container(
                width: double.infinity,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isEdit ? 'حفظ التعديلات' : 'إنشاء التنبيه',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                  ),
                ),
              )
            else
              // Active Red Button
              InkWell(
                onTap: _isSaving ? null : _save,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC1121F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'حفظ التعديلات' : 'إنشاء التنبيه',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
