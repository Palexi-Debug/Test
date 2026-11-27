import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/view/dashboard/dashboard_layout.dart';

void main() {
  test('Standardkacheln füllen das Raster zeilenweise', () {
    final l = placeTiles(['a', 'b', 'c'], {}, 2);
    expect(l.rows, 2);
    expect(l.placed['a']!.col, 0);
    expect(l.placed['b']!.col, 1);
    expect(l.placed['c']!.row, 1);
  });

  test('Breite wird auf die Spaltenzahl begrenzt', () {
    final l = placeTiles(['a'], {'a': const TileSpan(4, 1)}, 2);
    expect(l.placed['a']!.w, 2);
  });

  test('Hohe Kachel lässt Lücken für die nächsten füllen', () {
    final l = placeTiles(
      ['a', 'b', 'c'],
      {'a': const TileSpan(1, 2)},
      2,
    );
    expect(l.placed['a']!.h, 2);
    expect(l.placed['b']!.col, 1);
    expect(l.placed['c']!.col, 1);
    expect(l.placed['c']!.row, 1);
    expect(l.rows, 2);
  });

  test('Speichern und Laden, Migration vom alten Format', () {
    final spans = {'a': const TileSpan(2, 3)};
    expect(decodeSpans(encodeSpans(spans), null)['a'], const TileSpan(2, 3));
    final legacy = decodeSpans('', '{"x":1,"y":2}');
    expect(legacy['x'], const TileSpan(2, 1));
    expect(legacy['y'], const TileSpan(2, 2));
    expect(decodeSpans('{}', '{"x":1}'), isEmpty);
  });
}
