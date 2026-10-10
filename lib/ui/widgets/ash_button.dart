import 'package:flutter/material.dart';

import '../../services/audio.dart';
import '../theme.dart';

/// 청동 판에 금테를 두른 픽셀풍 버튼. 모서리가 각지고 그림자가 번지지 않는다.
class AshButton extends StatefulWidget {
  const AshButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fontSize = 20,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double fontSize;

  @override
  State<AshButton> createState() => _AshButtonState();
}

class _AshButtonState extends State<AshButton> {
  bool _hover = false;
  bool _down = false;

  void _tap() {
    GameAudio.play(Sfx.tap);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final lit = enabled && (_hover || _down);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: enabled ? _tap : null,
          child: AnimatedScale(
            scale: _down ? 0.96 : 1,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.symmetric(
                horizontal: widget.fontSize * 1.6,
                vertical: widget.fontSize * 0.6,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled
                      ? const [Color(0xFF4A3B2C), Color(0xFF241A12)]
                      : const [Color(0xFF2E2925), Color(0xFF1A1714)],
                ),
                border: Border.all(
                  color: enabled ? AshColors.gold : AshColors.ash,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(0, _down ? 1 : 4),
                  ),
                  if (lit)
                    BoxShadow(
                      color: AshColors.ember.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                ],
              ),
              // 버튼이 넓게 늘어나도 글씨는 가운데에 둔다.
              child: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 좁은 자리에서는 글씨를 줄여 버튼 안에 다 보이게 한다.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: enabled
                                ? AshColors.parchment
                                : AshColors.ash,
                            fontFamily: pixelFont,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: widget.fontSize * 0.08,
                          ),
                        ),
                      ),
                    ),
                    if (widget.icon != null) ...[
                      SizedBox(width: widget.fontSize * 0.5),
                      Icon(
                        widget.icon,
                        color: AshColors.gold,
                        size: widget.fontSize,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
