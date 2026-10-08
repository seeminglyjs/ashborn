import 'package:flutter/material.dart';

import '../theme.dart';

/// 청동 판에 금테를 두른 버튼. 타이틀 원화의 버튼 스타일을 따른다.
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
          onTap: widget.onPressed,
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
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: enabled
                      ? const [Color(0xFF4A3B2C), Color(0xFF241A12)]
                      : const [Color(0xFF2E2925), Color(0xFF1A1714)],
                ),
                border: Border.all(
                  color: enabled ? AshColors.gold : AshColors.ash,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AshColors.ember.withValues(alpha: lit ? 0.55 : 0.2),
                    blurRadius: lit ? 24 : 12,
                  ),
                ],
              ),
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
                          color: enabled ? AshColors.parchment : AshColors.ash,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: widget.fontSize * 0.15,
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
    );
  }
}
