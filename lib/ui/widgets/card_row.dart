import 'package:flutter/material.dart';

/// 고르는 카드(레벨업 · 은총)를 위에서 아래로 한 장씩 쌓는다. 카드는 화면 폭을 넓게 쓰는
/// 가로형(왼쪽 그림, 오른쪽 글)이고, 넓은 화면에서는 [maxWidth] 를 넘지 않게 가운데 둔다.
class CardColumn extends StatelessWidget {
  const CardColumn({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.spacing = 8,
    this.maxWidth = 480,
  });

  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double spacing;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            itemBuilder(context, i),
          ],
        ],
      ),
    ),
  );
}

/// 낱말 안에서는 줄이 바뀌지 않게 한다. 한글은 글자 사이에서도 줄이 바뀌어
/// "다이코쿠/텐" 처럼 낱말이 쪼개지므로, 띄어쓰기가 아닌 글자 사이마다 보이지 않는
/// 이음표(U+2060 WORD JOINER)를 넣어 띄어쓰기에서만 줄이 바뀌게 한다.
String keepWords(String text) {
  final out = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (i > 0 && c.trim().isNotEmpty && text[i - 1].trim().isNotEmpty) {
      out.write('⁠');
    }
    out.write(c);
  }
  return out.toString();
}

/// 한 줄에 다 들어가게 글자를 줄여서라도 한 줄로 쓰는 이름 (신 이름 · 무기 이름).
class OneLineText extends StatelessWidget {
  const OneLineText(
    this.text, {
    super.key,
    required this.style,
    this.center = false,
  });

  final String text;
  final TextStyle style;
  final bool center;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: center ? Alignment.center : Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    ),
  );
}

/// 선택 화면 전체를 한 화면에 담는다. 화면 폭은 그대로 쓰고, 세로로 넘치면 스크롤 대신
/// 전체를 같은 비율로 줄여 모든 카드가 늘 한 번에 보이게 한다.
class FitOneScreen extends StatelessWidget {
  const FitOneScreen({super.key, required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth - padding.horizontal;
      return Padding(
        padding: padding,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(width: width, child: child),
          ),
        ),
      );
    },
  );
}
