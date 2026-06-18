import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/models.dart';

class MiniCoverDisc extends StatefulWidget {
  const MiniCoverDisc({super.key, required this.novel, required this.playing});

  final Novel novel;
  final bool playing;

  @override
  State<MiniCoverDisc> createState() => _MiniCoverDiscState();
}

class _MiniCoverDiscState extends State<MiniCoverDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    super.initState();
    _syncRotation();
  }

  @override
  void didUpdateWidget(covariant MiniCoverDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      _syncRotation();
    }
  }

  void _syncRotation() {
    if (widget.playing) {
      _rotation.repeat();
    } else {
      _rotation.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.novel.coverUrl?.trim();
    final coverAsset = widget.novel.coverAsset;
    return RotationTransition(
      turns: _rotation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: appInk(context).withValues(alpha: 0.16),
          border: Border.all(color: Colors.orange, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(
                alpha: widget.playing ? 0.38 : 0.2,
              ),
              blurRadius: widget.playing ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.music_note, color: Colors.orange),
                    )
                  : coverAsset != null
                  ? Image.asset(coverAsset, fit: BoxFit.cover)
                  : const Icon(Icons.music_note, color: Colors.orange),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.16),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                    stops: const [0.28, 0.52, 0.68, 1],
                  ),
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.75,
              child: Container(
                width: 8,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.38),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: appPaper(context),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.86),
                  width: 2.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
