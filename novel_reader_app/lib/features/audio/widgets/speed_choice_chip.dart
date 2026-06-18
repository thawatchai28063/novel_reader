import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';

class SpeedChoiceChip extends StatelessWidget {
  const SpeedChoiceChip({
    super.key,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final double value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final label = '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}x';
    return AnimatedTapSurface(
      onTap: onSelected,
      padding: EdgeInsets.zero,
      color: selected ? Colors.orange : appPaper(context),
      pressedColor: Colors.orange.withValues(alpha: 0.22),
      borderColor: selected
          ? Colors.orange
          : appInk(context).withValues(alpha: 0.08),
      elevation: selected ? 8 : 2,
      child: SizedBox(
        height: 44,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? Colors.white : appInk(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
