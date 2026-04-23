import 'package:flutter/material.dart';

import '../data/country_options.dart';

class CountryPickerFormField extends FormField<String> {
  CountryPickerFormField({
    super.key,
    required String label,
    required String hintText,
    required InputDecoration decoration,
    required Color sheetBackgroundColor,
    required Color accentColor,
    String? initialValue,
    bool enabled = true,
    bool showLabel = true,
    bool showSearchIcon = true,
    Widget Function(CountryOption country)? selectedBuilder,
    String? Function(String?)? validator,
    ValueChanged<String?>? onChanged,
  }) : super(
          initialValue: initialValue,
          enabled: enabled,
          validator: validator,
          builder: (field) {
            final selectedCountry = countryOptionByCode(field.value);
            final labelStyle = decoration.labelStyle ??
                const TextStyle(
                  color: Colors.black54,
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                );
            final effectiveDecoration = InputDecoration(
              enabled: enabled,
              filled: decoration.filled,
              fillColor: decoration.fillColor,
              contentPadding: decoration.contentPadding,
              isCollapsed: decoration.isCollapsed,
              isDense: decoration.isDense,
              border: decoration.border,
              enabledBorder: decoration.enabledBorder,
              disabledBorder: decoration.disabledBorder,
              focusedBorder: decoration.focusedBorder,
              errorBorder: decoration.errorBorder,
              focusedErrorBorder: decoration.focusedErrorBorder,
              constraints: decoration.constraints,
              prefixIcon: decoration.prefixIcon,
              prefixIconConstraints: decoration.prefixIconConstraints,
              suffixIcon: showSearchIcon
                  ? Icon(
                      Icons.search_rounded,
                      color: enabled
                          ? accentColor
                          : accentColor.withValues(alpha: 0.4),
                    )
                  : null,
              suffixIconConstraints: decoration.suffixIconConstraints,
            ).applyDefaults(Theme.of(field.context).inputDecorationTheme);

            Future<void> openPicker() async {
              if (!enabled) return;
              final result = await showModalBottomSheet<CountryOption>(
                context: field.context,
                isScrollControlled: true,
                backgroundColor: sheetBackgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => _CountrySearchSheet(
                  selectedCode: field.value,
                  accentColor: accentColor,
                  backgroundColor: sheetBackgroundColor,
                ),
              );

              if (result == null) return;
              field.didChange(result.code);
              onChanged?.call(result.code);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showLabel) ...<Widget>[
                  Text(label, style: labelStyle),
                  const SizedBox(height: 6),
                ],
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: enabled ? openPicker : null,
                    borderRadius: BorderRadius.circular(14),
                    child: IgnorePointer(
                      child: InputDecorator(
                        isEmpty: selectedCountry == null,
                        isFocused: false,
                        decoration: effectiveDecoration,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: selectedCountry == null
                              ? Text(
                                  hintText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: decoration.hintStyle ??
                                      TextStyle(
                                        color: Colors.black.withValues(
                                          alpha: 0.42,
                                        ),
                                        fontFamily: 'Tajawal',
                                        fontWeight: FontWeight.w700,
                                      ),
                                )
                              : (selectedBuilder?.call(selectedCountry) ??
                                  _DefaultCountryValue(
                                    country: selectedCountry,
                                    stacked: true,
                                  )),
                        ),
                      ),
                    ),
                  ),
                ),
                if (field.errorText case final error?)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: 8,
                      start: 12,
                    ),
                    child: Text(
                      error,
                      style: decoration.errorStyle ??
                          const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            );
          },
        );
}

class _CountrySearchSheet extends StatefulWidget {
  const _CountrySearchSheet({
    required this.selectedCode,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String? selectedCode;
  final Color accentColor;
  final Color backgroundColor;

  @override
  State<_CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<_CountrySearchSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CountryOption> get _filteredCountries {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return kCountryOptions;
    }

    return kCountryOptions
        .where((country) => country.searchableText.contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final filteredCountries = _filteredCountries;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن الدولة',
                    hintStyle: TextStyle(
                      color: Colors.black.withValues(alpha: 0.42),
                      fontFamily: 'Tajawal',
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: widget.accentColor,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.accentColor.withValues(alpha: 0.22),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.accentColor.withValues(alpha: 0.22),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: widget.accentColor.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filteredCountries.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد نتائج مطابقة',
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.65),
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: filteredCountries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final country = filteredCountries[index];
                          final selected = country.code ==
                              widget.selectedCode?.trim().toUpperCase();

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(country),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? widget.accentColor.withValues(alpha: 0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: widget.accentColor.withValues(
                                      alpha: selected ? 0.42 : 0.14,
                                    ),
                                  ),
                                ),
                                child: _DefaultCountryValue(
                                  country: country,
                                  isSelected: selected,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultCountryValue extends StatelessWidget {
  const _DefaultCountryValue({
    required this.country,
    this.isSelected = false,
    this.stacked = false,
  });

  final CountryOption country;
  final bool isSelected;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected ? Colors.black : Colors.black87;
    final secondaryColor = Colors.black.withValues(alpha: 0.58);

    if (stacked) {
      return Row(
        children: <Widget>[
          Text(
            country.flagEmoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  country.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foregroundColor,
                    fontFamily: 'Tajawal',
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  country.dialCode,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: secondaryColor,
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Text(
          country.flagEmoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            country.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontFamily: 'Tajawal',
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          country.dialCode,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: secondaryColor,
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
