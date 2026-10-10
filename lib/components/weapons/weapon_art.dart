import 'dart:ui';

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
    'o': Color(0xFF17131C),
    'y': Color(0xFFE8B84A),
    'Y': Color(0xFF9C6A22),
    'r': Color(0xFFD8344A),
    'R': Color(0xFFFF8C96),
    'b': Color(0xFF6E4228),
    'B': Color(0xFFA36A44),
    'i': Color(0xFF3E4250),
    'I': Color(0xFF8C93A6),
    'J': Color(0xFFC4CAD8),
    'w': Color(0xFFF6F9FF),
    's': Color(0xFFCDD6E4),
    'm': Color(0xFF96A2B8),
    'd': Color(0xFF606A84),
    'f': Color(0xFF76829C),
  },
);

/// 대검을 쥐는 자리 (손잡이 가운데) 와 칼끝까지의 픽셀 길이.
const greatswordGrip = Offset(8, 7);
const double greatswordReachPixels = 42;

const _steelPalette = {
  'o': Color(0xFF17131C),
  'S': Color(0xFFBEC8D8),
  'W': Color(0xFFF6F9FF),
  'M': Color(0xFF78829A),
  'b': Color(0xFF6E4228),
  'B': Color(0xFFA36A44),
  'f': Color(0xFF962828),
  'F': Color(0xFFDC5046),
  'y': Color(0xFFE8B84A),
  'Y': Color(0xFF9C6A22),
  'I': Color(0xFF8C93A6),
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
