import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../app_modal.dart';
import 'player_settings_fields.dart';
import 'player_settings_option.dart';

class PlayerSettingsDialog extends AppModal<Object> {
  const PlayerSettingsDialog({
    required this.sources,
    required this.source,
    required this.onSourceChanged,
    required this.speeds,
    required this.speed,
    required this.onSpeedChanged,
    required this.subtitles,
    required this.subtitleUrl,
    required this.onSubtitleChanged,
    required this.subtitleSize,
    required this.onSubtitleSizeChanged,
    required this.subtitleColor,
    required this.onSubtitleColorChanged,
    required this.subtitleBackground,
    required this.onSubtitleBackgroundChanged,
  });

  final List<PlayerSettingsOption<String>> sources;
  final String source;
  final ValueChanged<String> onSourceChanged;
  final List<PlayerSettingsOption<double>> speeds;
  final double speed;
  final ValueChanged<double> onSpeedChanged;
  final List<PlayerSettingsOption<String?>> subtitles;
  final String? subtitleUrl;
  final ValueChanged<String?> onSubtitleChanged;
  final double subtitleSize;
  final ValueChanged<double> onSubtitleSizeChanged;
  final SubtitleColor subtitleColor;
  final ValueChanged<SubtitleColor> onSubtitleColorChanged;
  final double subtitleBackground;
  final ValueChanged<double> onSubtitleBackgroundChanged;

  @override
  Future<Object?> show(BuildContext context) {
    return AppDialog<Object>(
      title: 'Player settings',
      builder: (_) => _PlayerSettingsView(settings: this),
    ).show(context);
  }
}

class _PlayerSettingsView extends StatefulWidget {
  const _PlayerSettingsView({required this.settings});

  final PlayerSettingsDialog settings;

  @override
  State<_PlayerSettingsView> createState() => _PlayerSettingsViewState();
}

class _PlayerSettingsViewState extends State<_PlayerSettingsView> {
  late String _source;
  late double _speed;
  late String? _subtitleUrl;
  late double _subtitleSize;
  late SubtitleColor _subtitleColor;
  late double _subtitleBackground;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _source = settings.source;
    _speed = settings.speed;
    _subtitleUrl = settings.subtitleUrl;
    _subtitleSize = settings.subtitleSize;
    _subtitleColor = settings.subtitleColor;
    _subtitleBackground = settings.subtitleBackground;
  }

  void _selectSource(String? value) {
    if (value == null || value == _source) return;
    setState(() {
      _source = value;
      _subtitleUrl = null;
    });
    widget.settings.onSourceChanged(value);
  }

  void _selectSpeed(double? value) {
    if (value == null || value == _speed) return;
    setState(() => _speed = value);
    widget.settings.onSpeedChanged(value);
  }

  void _selectSubtitle(String? value) {
    if (value == _subtitleUrl) return;
    setState(() => _subtitleUrl = value);
    widget.settings.onSubtitleChanged(value);
  }

  void _changeSubtitleSize(double value) {
    setState(() => _subtitleSize = value);
    widget.settings.onSubtitleSizeChanged(value);
  }

  void _changeSubtitleColor(SubtitleColor? value) {
    if (value == null || value == _subtitleColor) return;
    setState(() => _subtitleColor = value);
    widget.settings.onSubtitleColorChanged(value);
  }

  void _changeSubtitleBackground(double value) {
    setState(() => _subtitleBackground = value);
    widget.settings.onSubtitleBackgroundChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsDropdownRow<String>(
            label: 'Stream source',
            value: _source,
            options: settings.sources,
            onChanged: _selectSource,
          ),
          SettingsDropdownRow<double>(
            label: 'Playback speed',
            value: _speed,
            options: settings.speeds,
            labelFor: (value) => '${value.toStringAsFixed(2)}x',
            onChanged: _selectSpeed,
          ),
          SettingsDropdownRow<String?>(
            label: 'Subtitle track',
            value: _subtitleUrl,
            options: settings.subtitles,
            onChanged: _selectSubtitle,
          ),
          SettingsSliderRow(
            label: 'Subtitle size',
            value: _subtitleSize,
            labelText: '${_subtitleSize.round()}',
            min: 14,
            max: 72,
            divisions: 29,
            onChanged: _changeSubtitleSize,
          ),
          SettingsDropdownRow<SubtitleColor>(
            label: 'Subtitle color',
            value: _subtitleColor,
            options: [
              for (final color in SubtitleColor.values)
                PlayerSettingsOption(value: color, label: color.label),
            ],
            onChanged: _changeSubtitleColor,
          ),
          SettingsSliderRow(
            label: 'Subtitle background',
            value: _subtitleBackground,
            labelText: _subtitleBackground == 0
                ? 'Off'
                : '${(_subtitleBackground * 100).round()}%',
            min: 0,
            max: 0.9,
            divisions: 9,
            onChanged: _changeSubtitleBackground,
          ),
        ],
      ),
    );
  }
}
