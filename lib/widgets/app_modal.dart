import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

abstract class AppModal<T> {
  const AppModal();

  Future<T?> show(BuildContext context);
}

class AppDialog<T> extends AppModal<T> {
  const AppDialog({
    required this.builder,
    this.title,
    this.maxWidth = 440,
  });

  final WidgetBuilder builder;
  final String? title;
  final double maxWidth;

  @override
  Future<T?> show(BuildContext context) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        Widget content = builder(dialogContext);
        final heading = title;
        if (heading != null) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Text(
                        heading,
                        style: dialogContext.appTextTheme.titleMedium?.copyWith(
                          color: dialogContext.appOnSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    tooltip: 'Close',
                    icon: Icon(
                      Icons.close_rounded,
                      color: dialogContext.appOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
              content,
            ],
          );
        }
        return Dialog(
          backgroundColor: dialogContext.appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.82,
          ),
          child: SafeArea(child: content),
        );
      },
    );
  }
}

class AppBottomSheet<T> extends AppModal<T> {
  const AppBottomSheet({
    required this.builder,
    this.title,
    this.maxHeightFactor,
    this.isScrollControlled = false,
    this.respondToKeyboard = false,
  });

  final WidgetBuilder builder;
  final String? title;
  final double? maxHeightFactor;
  final bool isScrollControlled;
  final bool respondToKeyboard;

  @override
  Future<T?> show(BuildContext context) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled:
          isScrollControlled || maxHeightFactor != null || respondToKeyboard,
      builder: (sheetContext) {
        Widget content = builder(sheetContext);
        final heading = title;
        if (heading != null) {
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  heading,
                  style: sheetContext.appTextTheme.titleMedium?.copyWith(
                    color: sheetContext.appOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              content,
            ],
          );
        }

        final factor = maxHeightFactor;
        if (factor != null) {
          content = ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * factor,
            ),
            child: content,
          );
        }

        if (respondToKeyboard) {
          content = Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: content,
          );
        }

        return SafeArea(child: content);
      },
    );
  }
}

class AppConfirmDialog extends AppModal<bool> {
  const AppConfirmDialog({
    required this.message,
    this.title = 'Confirm',
    this.confirmLabel = 'Yes',
    this.cancelLabel = 'No',
  });

  final String message;
  final String title;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Future<bool?> show(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: dialogContext.appTextTheme.labelSmall?.copyWith(
            letterSpacing: 2,
          ),
        ),
        content: Text(message, style: dialogContext.appTextTheme.bodyLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: dialogContext.appAccent),
            ),
          ),
        ],
      ),
    );
  }
}
