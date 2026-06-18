import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class AudioPlaylistRailButton extends StatelessWidget {
  const AudioPlaylistRailButton({
    super.key,
    required this.open,
    required this.clipCount,
    required this.onPressed,
  });

  final bool open;
  final int clipCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: appSage(context),
      elevation: 8,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      child: InkWell(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 190),
          curve: Curves.easeOut,
          width: 32,
          height: 112,
          decoration: BoxDecoration(
            color: open ? Colors.orange : appSage(context),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                open ? Icons.chevron_left : Icons.queue_music,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(height: 6),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  clipCount > 0 ? '$clipCount คลิป' : 'คลิป',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
