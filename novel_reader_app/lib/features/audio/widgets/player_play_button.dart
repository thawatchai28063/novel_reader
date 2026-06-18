import 'package:flutter/material.dart';

class PlayerPlayButton extends StatelessWidget {
  const PlayerPlayButton({
    super.key,
    required this.loading,
    required this.playing,
    required this.onPressed,
  });

  final bool loading;
  final bool playing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing ? 'หยุดชั่วคราว' : 'เล่น',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB12E), Color(0xFFFF7A00)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: loading ? 0.18 : 0.42),
              blurRadius: loading ? 10 : 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Transform.translate(
                      offset: playing ? Offset.zero : const Offset(3, 0),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
