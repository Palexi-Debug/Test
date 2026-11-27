import 'dart:convert';

/// Größe einer Kachel in Rasterzellen (Breite x Höhe).
class TileSpan {
  final int w;
  final int h;
  const TileSpan(this.w, this.h);

  static const unit = TileSpan(1, 1);
  static const maxHeight = 4;

  /// Passt die Größe an die Spaltenzahl an.
  TileSpan clamped(int columns) => TileSpan(
    w.clamp(1, columns < 1 ? 1 : columns).toInt(),
    h.clamp(1, maxHeight).toInt(),
  );

  bool get isUnit => w == 1 && h == 1;

  @override
  bool operator ==(Object other) =>
      other is TileSpan && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(w, h);

  @override
  String toString() => '${w}x$h';
}

/// Position einer Kachel im Raster.
class TilePlacement {
  final int row;
  final int col;
  final int w;
  final int h;
  const TilePlacement(this.row, this.col, this.w, this.h);
}

class TileLayout {
  final Map<String, TilePlacement> placed;
  final int rows;
  const TileLayout(this.placed, this.rows);
}

/// Liest gespeicherte Größen. Neues Format: {"id":[w,h]}. Altes Format
/// (Stufen 0 klein, 1 breit, 2 groß) wird übernommen, solange es kein neues gibt.
Map<String, TileSpan> decodeSpans(String? spansJson, String? legacyJson) {
  final out = <String, TileSpan>{};
  try {
    final raw = (spansJson ?? '').trim();
    if (raw.isNotEmpty && raw != '{}') {
      final map = jsonDecode(raw) as Map;
      map.forEach((k, v) {
        if (v is List && v.length == 2) {
          final span = TileSpan(
            (v[0] as num).toInt(),
            (v[1] as num).toInt(),
          );
          if (!span.isUnit) out[k as String] = span;
        }
      });
      return out;
    }
    final legacy = (legacyJson ?? '').trim();
    if (legacy.isNotEmpty) {
      final map = jsonDecode(legacy) as Map;
      map.forEach((k, v) {
        final step = (v as num).toInt();
        if (step == 1) out[k as String] = const TileSpan(2, 1);
        if (step >= 2) out[k as String] = const TileSpan(2, 2);
      });
    }
  } catch (_) {}
  return out;
}

String encodeSpans(Map<String, TileSpan> spans) => jsonEncode({
  for (final e in spans.entries)
    if (!e.value.isUnit) e.key: [e.value.w, e.value.h],
});

/// Einfache Raster-Platzierung: jede Kachel kommt an die erste freie Stelle,
/// auf die sie passt. Lücken füllen sich dadurch automatisch.
TileLayout placeTiles(
  List<String> ids,
  Map<String, TileSpan> spans,
  int columns,
) {
  final cols = columns < 1 ? 1 : columns;
  final occ = <List<bool>>[];
  final placed = <String, TilePlacement>{};

  bool fits(int r, int c, int w, int h) {
    if (c + w > cols) return false;
    for (var rr = r; rr < r + h && rr < occ.length; rr++) {
      for (var cc = c; cc < c + w; cc++) {
        if (occ[rr][cc]) return false;
      }
    }
    return true;
  }

  for (final id in ids) {
    final span = (spans[id] ?? TileSpan.unit).clamped(cols);
    var done = false;
    for (var r = 0; !done; r++) {
      for (var c = 0; c + span.w <= cols && !done; c++) {
        if (!fits(r, c, span.w, span.h)) continue;
        while (occ.length < r + span.h) {
          occ.add(List<bool>.filled(cols, false));
        }
        for (var rr = r; rr < r + span.h; rr++) {
          for (var cc = c; cc < c + span.w; cc++) {
            occ[rr][cc] = true;
          }
        }
        placed[id] = TilePlacement(r, c, span.w, span.h);
        done = true;
      }
    }
  }
  return TileLayout(placed, occ.length);
}
