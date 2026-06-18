import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class PlayerControlButton extends StatelessWidget {
  const PlayerControlButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Icon icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled
        ? appSage(context)
        : appInk(context).withValues(alpha: 0.28);
    return Tooltip(
      message: tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        opacity: enabled ? 1 : 0.48,
        child: AnimatedTapSurface(
          onTap: onPressed,
          padding: EdgeInsets.zero,
          color: appPaper(context),
          pressedColor: appSage(context).withValues(alpha: 0.14),
          borderColor: appInk(context).withValues(alpha: 0.08),
          elevation: enabled ? 8 : 0,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon.icon, color: foreground, size: 26),
          ),
        ),
      ),
    );
  }
}
