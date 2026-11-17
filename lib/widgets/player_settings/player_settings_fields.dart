import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'player_settings_option.dart';

class SettingsDropdownRow<T> extends StatelessWidget {
  const SettingsDropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelFor,
  });

  final String label;
  final T? value;
  final List<PlayerSettingsOption<T>> options;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelFor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<T?>(
              value: value,
              isExpanded: true,
              isDense: true,
              menuMaxHeight: 280,
              dropdownColor: context.appSurface,
              style: context.appTextTheme.bodyMedium?.copyWith(
                color: context.appOnSurface,
              ),
              decoration: settingsFieldDecoration(context),
              items: [
                for (final option in options)
                  DropdownMenuItem<T?>(
                    value: option.value,
                    child: Text(
                      labelFor?.call(option.value) ?? option.label,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsSliderRow extends StatelessWidget {
  const SettingsSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.labelText,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String labelText;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                label,
                style: context.appTextTheme.bodyMedium?.copyWith(
                  color: context.appOnSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                labelText,
                style: context.appTextTheme.labelMedium?.copyWith(
                  color: context.appAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: context.appAccent,
            inactiveColor: context.appSurfaceVariant,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

InputDecoration settingsFieldDecoration(BuildContext context) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: context.appSurfaceVariant),
  );
  return InputDecoration(
    filled: true,
    fillColor: context.appSurfaceAlt,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: context.appAccent),
    ),
  );
}
