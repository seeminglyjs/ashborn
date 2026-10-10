import 'dart:ui';

/// 게임 전체가 함께 쓰는 고정 팔레트 Endesga 32 (Lospec 공개 팔레트) 의 색.
/// 새로 그리는 픽셀 그림은 이 색만 쓴다 (tool/assets/palette.py 와 같은 표).
abstract final class Pal {
  static const outline = Color(0xFF181425);
  static const white = Color(0xFFFFFFFF);
  static const steelLight = Color(0xFFC0CBDC);
  static const steel = Color(0xFF8B9BB4);
  static const steelDark = Color(0xFF5A6988);
  static const steelDeep = Color(0xFF3A4466);
  static const goldLight = Color(0xFFFEE761);
  static const gold = Color(0xFFFEAE34);
  static const goldDark = Color(0xFFD77643);
  static const leatherLight = Color(0xFFB86F50);
  static const leather = Color(0xFF733E39);
  static const red = Color(0xFFE43B44);
  static const redDark = Color(0xFFA22633);
  static const pink = Color(0xFFF6757A);
}

/// 글자 격자로 적은 작은 픽셀 그림. 한 번 그려 [Picture] 로 들고 있다가 돌리고 키워서 쓴다.
///
/// [rows] 의 글자 하나가 한 픽셀이고, '.' 은 비운다. 색은 [palette] 에서 찾는다.
class PixelArt {
  PixelArt(this.rows, this.palette)
    : width = rows.fold(0, (w, r) => r.length > w ? r.length : w),
      height = rows.length {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    for (var y = 0; y < rows.length; y++) {
      final row = rows[y];
      for (var x = 0; x < row.length; x++) {
        final color = palette[row[x]];
        if (color == null) continue;
        paint.color = color;
        // 이웃 픽셀과 틈이 보이지 않도록 아주 조금 겹쳐 그린다.
        canvas.drawRect(Rect.fromLTWH(x - 0.02, y - 0.02, 1.04, 1.04), paint);
      }
    }
    picture = recorder.endRecording();
  }

  final List<String> rows;
  final Map<String, Color> palette;
  final int width;
  final int height;
  late final Picture picture;

  /// 픽셀 ([pivot]) 이 지금 원점에 오도록, 한 픽셀을 [scale] 크기로 그린다.
  void draw(Canvas canvas, {required Offset pivot, double scale = 1}) {
    canvas
      ..save()
      ..scale(scale)
      ..translate(-pivot.dx, -pivot.dy)
      ..drawPicture(picture)
      ..restore();
  }
}

/// 강철 대검 (잿불 기사). 오른쪽이 칼끝, 손잡이는 (7, 7) 근처.
final greatswordArt = PixelArt(
  const [
    '............oo....................................',
    '...........oyyo...................................',
    '...........oYyo...................................',
    '...........oiIo...................................',
    '..ooo......oiIoooooooooooooooooooooooooooooo......',
    '.oyyyo.ooooiIJowwwwwwwwwwwwwwwwwwwwwwwwwwwwwoo....',
    'oyRryooBbBbiIJosssssssssssssssssssssssssssssswoo..',
    'oyrryoobBbBiIJommfffffffffffffffffffffffffssssswoo',
    'oYyyYooBbBbiIJommmmmmmmmmmmmmmmmmmmmmmmmmmmmmmoo..',
    '.oYYYo.ooooiIJodddddddddddddddddddddddddddddoo....',
    '..ooo......oiIoooooooooooooooooooooooooooooo......',
    '...........oiIo...................................',
    '...........oYyo...................................',
    '...........oyyo...................................',
    '............oo....................................',
  ],
  const {
    'o': Pal.outline,
    'y': Pal.gold,
    'Y': Pal.goldDark,
    'r': Pal.red,
    'R': Pal.pink,
    'b': Pal.leather,
    'B': Pal.leatherLight,
    'i': Pal.steelDeep,
    'I': Pal.steel,
    'J': Pal.steelLight,
    'w': Pal.white,
    's': Pal.steelLight,
    'm': Pal.steel,
    'd': Pal.steelDeep,
    // 홈(fuller)은 날 가운데보다 한 단계 어둡게.
    'f': Pal.steelDark,
  },
);

/// 대검을 쥐는 자리 (손잡이 가운데) 와 칼끝까지의 픽셀 길이.
const greatswordGrip = Offset(8, 7);
const double greatswordReachPixels = 42;

const _steelPalette = {
  'o': Pal.outline,
  'S': Pal.steelLight,
  'W': Pal.white,
  'M': Pal.steelDark,
  'b': Pal.leather,
  'B': Pal.leatherLight,
  'f': Pal.redDark,
  'F': Pal.red,
  'y': Pal.gold,
  'Y': Pal.goldDark,
  'I': Pal.steel,
};

/// 사냥 석궁의 강철 화살. 오른쪽이 촉, 왼쪽이 붉은 깃.
final boltArt = PixelArt(const [
  'ff...........oo....',
  'fFf..........oSoo..',
  '.fFbbbbbbbbbboSWSo.',
  '..FBBBBBBBBBBoSWWWo',
  '.fFbbbbbbbbbboSMMo.',
  'fFf..........oMoo..',
  'ff...........oo....',
], _steelPalette);

/// 투척 단검. 오른쪽이 칼끝.
final knifeArt = PixelArt(const [
  '.......ooooo...',
  'oyo...oSWWWSoo.',
  'oYbBboISSSSSSSo',
  'oyo...oMMMMMoo.',
  '.......ooooo...',
], _steelPalette);

/// 회전 차크람: 강철 고리와 금빛 갈고리 날 넷.
final chakramArt = PixelArt(const [
  '.........Y.......',
  '.........yyY.....',
  '......oooooyy....',
  '....ooWWWWSoo....',
  '..yooWWWWSSSoo...',
  '.YyoWWWoooSSSo...',
  '.yoWWWo...oSSSo..',
  'YyoWWo.....oSSo..',
  '..oWWo.....oSSo..',
  '..oWMo.....oMMoyY',
  '..oMMMo...oMMMoy.',
  '...oMMMoooMMMoyY.',
  '...ooMMMMMMMooy..',
  '....ooMMMMMoo....',
  '....yyooooo......',
  '.....Yyy.........',
  '.......Y.........',
], _steelPalette);
