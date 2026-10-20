import 'package:flutter/material.dart';

import '../core/models/stock_model.dart';
import '../core/services/price_alerts_service.dart';
import '../core/services/stock_service.dart';
import '../core/utils/constants.dart';

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
        _showAddAlertDialog(preselected: widget.preselectedStock);
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

  void _showAddAlertDialog({StockModel? preselected}) {
    StockModel? selectedStock = preselected ?? (_allStocks.isNotEmpty ? _allStocks.first : null);
    final priceController = TextEditingController(
      text: selectedStock != null ? selectedStock.price.toStringAsFixed(2) : '',
    );
    AlertDirection direction = AlertDirection.above;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إضافة تنبيه سعر جديد',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stock Picker
                  Text('السهم', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.scaffold,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StockModel>(
                        value: selectedStock,
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        items: _allStocks.map((s) {
                          return DropdownMenuItem<StockModel>(
                            value: s,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.displayName,
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${s.price.toStringAsFixed(2)} ج.م',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedStock = val;
                              priceController.text = val.price.toStringAsFixed(2);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Direction Selector
                  Text('شرط التنبيه', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('عند الارتفاع إلى أو أعلى')),
                          selected: direction == AlertDirection.above,
                          selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                          backgroundColor: AppColors.scaffold,
                          labelStyle: TextStyle(
                            color: direction == AlertDirection.above ? AppColors.primaryBlue : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) setModalState(() => direction = AlertDirection.above);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('عند الانخفاض إلى أو أدنى')),
                          selected: direction == AlertDirection.below,
                          selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                          backgroundColor: AppColors.scaffold,
                          labelStyle: TextStyle(
                            color: direction == AlertDirection.below ? AppColors.primaryBlue : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (sel) {
                            if (sel) setModalState(() => direction = AlertDirection.below);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Target Price Input
                  Text('السعر المستهدف (ج.م)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.scaffold,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                        if (selectedStock != null && price > 0) {
                          await PriceAlertsService.instance.addAlert(
                            symbol: selectedStock!.symbol,
                            stockName: selectedStock!.displayName,
                            targetPrice: price,
                            direction: direction,
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('حفظ التنبيه', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: Text('تنبيهات الأسعار اللحظية', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_alert_rounded, color: AppColors.primaryBlue),
            tooltip: 'إضافة تنبيه',
            onPressed: () => _showAddAlertDialog(),
          ),
        ],
      ),
      body: _loadingStocks
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<StockPriceAlert>>(
              valueListenable: PriceAlertsService.instance.alertsNotifier,
              builder: (context, alerts, _) {
                if (alerts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد تنبيهات أسعار نشطة',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'يمكنك إنشاء تنبيه لأي سهم لتصلك إشعارات لحظية عبر LiveSocket فور وصول السعر للهدف.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showAddAlertDialog(),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('إضافة تنبيه جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (ctx, i) {
                    final alert = alerts[i];
                    return Dismissible(
                      key: Key(alert.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        PriceAlertsService.instance.removeAlert(alert.id);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: alert.isTriggered
                                ? AppColors.gain.withOpacity(0.3)
                                : Colors.black.withOpacity(0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: alert.isTriggered
                                    ? AppColors.gain.withOpacity(0.12)
                                    : AppColors.primaryBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                alert.isTriggered
                                    ? Icons.check_circle_outline_rounded
                                    : (alert.direction == AlertDirection.above
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded),
                                color: alert.isTriggered ? AppColors.gain : AppColors.primaryBlue,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.stockName,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${alert.direction.label} ${alert.targetPrice.toStringAsFixed(2)} ج.م',
                                    style: TextStyle(
                                      color: alert.isTriggered ? AppColors.gain : AppColors.textSecondary,
                                      fontSize: 13,
                                      fontWeight: alert.isTriggered ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  if (alert.isTriggered) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '✓ تم تنفيذ التنبيه',
                                      style: TextStyle(color: AppColors.gain, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Switch(
                              value: alert.isActive && !alert.isTriggered,
                              activeThumbColor: AppColors.primaryBlue,
                              onChanged: alert.isTriggered
                                  ? null
                                  : (_) => PriceAlertsService.instance.toggleAlert(alert.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
