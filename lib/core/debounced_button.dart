import 'package:flutter/material.dart';

/// A wrapper button that instantaneously deactivates on touch-down
/// to prevent duplicate clicks, double submissions, or race conditions.
class DebouncedElevatedButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Widget? icon;

  const DebouncedElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.icon,
  });

  @override
  State<DebouncedElevatedButton> createState() => _DebouncedElevatedButtonState();
}

class _DebouncedElevatedButtonState extends State<DebouncedElevatedButton> {
  bool _isSubmitting = false;

  Future<void> _handlePress() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await widget.onPressed();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.icon != null) {
      return ElevatedButton.icon(
        style: widget.style,
        icon: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : widget.icon!,
        label: widget.child,
        onPressed: _isSubmitting ? null : _handlePress,
      );
    }

    return ElevatedButton(
      style: widget.style,
      onPressed: _isSubmitting ? null : _handlePress,
      child: _isSubmitting
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 8),
                widget.child,
              ],
            )
          : widget.child,
    );
  }
}
