import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// How long the mouse has to rest before the bars go.
const idleDelay = Duration(seconds: 5);

/// Lays [top] and [bottom] over [body] and slides them off the edges once
/// the mouse has rested for [idleDelay]; moving it, or touching the
/// screen, brings them back.
///
/// The bars float over the body rather than taking room from it, so the
/// page underneath doesn't move or get laid out again as they come and go.
class AutoHideBars extends StatefulWidget {
  const AutoHideBars({
    super.key,
    required this.top,
    required this.body,
    this.bottom,
    this.hold = false,
  });

  final Widget top;
  final Widget body;
  final Widget? bottom;

  /// Keeps the bars on screen, as while something in them is being typed.
  final bool hold;

  @override
  State<AutoHideBars> createState() => _AutoHideBarsState();
}

class _AutoHideBarsState extends State<AutoHideBars> {
  var _hidden = false;
  Timer? _timer;

  /// Whether the mouse is resting on one of the bars, which keeps them.
  var _over = false;

  @override
  void initState() {
    super.initState();
    // Every pointer event in the window, wherever it lands, so a move over
    // a book beside this one counts too.
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _restart();
  }

  @override
  void didUpdateWidget(AutoHideBars old) {
    super.didUpdateWidget(old);
    if (widget.hold && _hidden) setState(() => _hidden = false);
    if (old.hold != widget.hold) _restart();
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    _timer?.cancel();
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    // The wheel and a finger scrolling the page leave the bars where they
    // are; reading on shouldn't bring them back.
    final wakes =
        event is PointerHoverEvent ||
        event is PointerDownEvent ||
        (event is PointerMoveEvent && event.kind == PointerDeviceKind.mouse);
    if (!wakes) return;
    if (_hidden) setState(() => _hidden = false);
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(idleDelay, () {
      if (!mounted || widget.hold || _over) return;
      setState(() => _hidden = true);
    });
  }

  Widget _bar(Widget child, Offset away) => IgnorePointer(
    ignoring: _hidden,
    child: AnimatedSlide(
      offset: _hidden ? away : Offset.zero,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: MouseRegion(
        onEnter: (_) => _over = true,
        onExit: (_) {
          _over = false;
          _restart();
        },
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottom = widget.bottom;
    return Stack(
      children: [
        Positioned.fill(child: widget.body),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _bar(widget.top, const Offset(0, -1)),
        ),
        if (bottom != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _bar(bottom, const Offset(0, 1)),
          ),
      ],
    );
  }
}
