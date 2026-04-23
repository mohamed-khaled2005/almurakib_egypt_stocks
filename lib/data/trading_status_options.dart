class TradingStatusOption {
  const TradingStatusOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

const String kTradingStatusQuestionLabel = 'ما الذي يصفك بشكل أفضل؟';

const List<TradingStatusOption> kTradingStatusOptions = <TradingStatusOption>[
  TradingStatusOption(value: 'yes', label: 'نعم أنا متداول'),
  TradingStatusOption(
    value: 'interested',
    label: 'لست متداولاً لكني مهتم بالتداول',
  ),
  TradingStatusOption(
    value: 'no',
    label: 'لست متداولاً وغير مهتم بالتداول',
  ),
  TradingStatusOption(value: 'investor', label: 'أنا مستثمر'),
];

TradingStatusOption? tradingStatusOptionByValue(String? rawValue) {
  final normalized = (rawValue ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }

  for (final option in kTradingStatusOptions) {
    if (option.value == normalized) {
      return option;
    }
  }

  return null;
}
