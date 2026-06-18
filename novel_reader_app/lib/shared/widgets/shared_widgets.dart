import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/models/models.dart';

class AnimatedTapSurface extends StatefulWidget {
  const AnimatedTapSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.color,
    this.pressedColor,
    this.borderColor,
    this.borderRadius = 8,
    this.elevation = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? pressedColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;

  @override
  State<AnimatedTapSurface> createState() => _AnimatedTapSurfaceState();
}

class _AnimatedTapSurfaceState extends State<AnimatedTapSurface> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final color = widget.color ?? appSurface(context);
    final pressedColor =
        widget.pressedColor ?? appSage(context).withValues(alpha: 0.10);
    final shadowAlpha = Theme.of(context).brightness == Brightness.dark
        ? 0.32
        : 0.10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
      decoration: BoxDecoration(
        color: _pressed ? pressedColor : color,
        borderRadius: radius,
        border: widget.borderColor == null
            ? null
            : Border.all(
                color: _pressed
                    ? appGold(context).withValues(alpha: 0.65)
                    : widget.borderColor!,
              ),
        boxShadow: [
          if (widget.elevation > 0)
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: _pressed ? widget.elevation * 0.55 : widget.elevation,
              offset: Offset(0, _pressed ? 4 : 8),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: widget.onTap,
          onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
          onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
          onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}

class NovelCover extends StatelessWidget {
  const NovelCover({
    super.key,
    required this.novel,
    this.width = 64,
    this.height = 86,
  });

  final Novel novel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final coverUrl = novel.coverUrl?.trim();
    final coverAsset = novel.coverAsset;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: appGold(context), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl != null && coverUrl.isNotEmpty
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  NovelCoverMark(title: novel.title),
            )
          : coverAsset != null
          ? Image.asset(coverAsset, fit: BoxFit.cover)
          : NovelCoverMark(title: novel.title),
    );
  }
}

class NovelCoverMark extends StatelessWidget {
  const NovelCoverMark({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final trimmed = title.trim();
    final initial = trimmed.isEmpty
        ? 'น'
        : String.fromCharCode(trimmed.runes.first);
    return Container(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF6F343C)
          : appRose,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Container(width: 2, color: Colors.white24),
          ),
          Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: 7,
            bottom: 7,
            child: Icon(Icons.bookmark, color: appGold(context), size: 18),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: appPaper(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: appSage(context)),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({
    super.key,
    required this.themeMode,
    required this.onPressed,
  });

  final ThemeMode themeMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (themeMode) {
      ThemeMode.system => (Icons.brightness_auto, 'ตามระบบ'),
      ThemeMode.light => (Icons.light_mode, 'โหมดสว่าง'),
      ThemeMode.dark => (Icons.dark_mode, 'โหมดมืด'),
    };
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) {
          return RotationTransition(
            turns: Tween<double>(begin: 0.08, end: 0).animate(animation),
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
          );
        },
        child: Icon(icon, key: ValueKey(themeMode)),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_library, size: 56),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีนิยาย',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}
