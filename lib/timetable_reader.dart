import 'dart:math' as math;
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

typedef TtEntry = ({String name, String slot, List<String> days, Map<String, String> daySlots});

class _Frag {
  final String text;
  final Rect box;
  _Frag(this.text, this.box);
  double get cx => box.center.dx;
  double get cy => box.center.dy;
}

final _dayRx = RegExp(r'^(mon|tue|wed|thu|fri|sat|sun)[a-z]*\.?$',
    caseSensitive: false);
final _timeRx = RegExp(r'(\d{1,2})\s*[:.]\s*(\d{2})\s*[-–—]\s*(\d{1,2})\s*[:.]\s*(\d{2})');
final _skipRx = RegExp(
    r'^(break|lunch|recess|day|time|library|sports?|free|lab)$',
    caseSensitive: false);

String _fmt(int h, String m) {
  final pm = h == 12 || h < 7;
  final h12 = h > 12 ? h - 12 : h;
  return '${h12.toString().padLeft(2, '0')}:$m ${pm ? 'PM' : 'AM'}';
}

/// Reads a grid timetable photo: days down the side, time ranges across the top.
/// Returns [] if no grid is found (caller falls back to plain text lines).
Future<List<TtEntry>> readTimetable(String path) async {
  final rec = TextRecognizer();
  try {
    final out = await rec.processImage(InputImage.fromFilePath(path));
    // 1) Split each OCR line into cell fragments at wide gaps.
    final frags = <_Frag>[];
    for (final b in out.blocks) {
      for (final l in b.lines) {
        final els = [...l.elements]
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
        if (els.isEmpty) continue;
        var cur = <TextElement>[els.first];
        void flush() {
          var r = cur.first.boundingBox;
          for (final e in cur) {
            r = r.expandToInclude(e.boundingBox);
          }
          frags.add(_Frag(cur.map((e) => e.text).join(' '), r));
        }

        for (final e in els.skip(1)) {
          final gap = e.boundingBox.left - cur.last.boundingBox.right;
          if (gap > 1.6 * e.boundingBox.height) {
            flush();
            cur = [e];
          } else {
            cur.add(e);
          }
        }
        flush();
      }
    }
    // 2) Day labels (rows) and time headers (columns).
    final dayFr = frags.where((f) => _dayRx.hasMatch(f.text.trim())).toList()
      ..sort((a, b) => a.cy.compareTo(b.cy));
    if (dayFr.length < 2) return [];
    final firstDayY = dayFr.first.cy;
    final heads = frags
        .where((f) => _timeRx.hasMatch(f.text) && f.cy < firstDayY)
        .toList()
      ..sort((a, b) => a.cx.compareTo(b.cx));
    if (heads.length < 2) return [];
    // 3) Correct photo tilt with the header line.
    final x0 = heads.map((f) => f.cx).reduce((a, b) => a + b) / heads.length;
    var slope = 0.0;
    if (heads.length >= 3) {
      final my = heads.map((f) => f.cy).reduce((a, b) => a + b) / heads.length;
      var num = 0.0, den = 0.0;
      for (final f in heads) {
        num += (f.cx - x0) * (f.cy - my);
        den += (f.cx - x0) * (f.cx - x0);
      }
      if (den > 0) slope = num / den;
    }
    double adj(_Frag f) => f.cy - slope * (f.cx - x0);
    final rowY = dayFr.map(adj).toList();
    final rowH = (rowY.last - rowY.first) / (rowY.length - 1);
    final colW = heads.length > 1
        ? (heads.last.cx - heads.first.cx) / (heads.length - 1)
        : 100.0;
    final slots = heads.map((f) {
      final m = _timeRx.firstMatch(f.text)!;
      return '${_fmt(int.parse(m.group(1)!), m.group(2)!)} - ${_fmt(int.parse(m.group(3)!), m.group(4)!)}';
    }).toList();
    String dayName(String t) {
      final k = t.trim().toLowerCase().substring(0, 3);
      return k[0].toUpperCase() + k.substring(1);
    }

    // 4) Drop every cell into (day, column) and group by subject name.
    final byKey = <String, ({String name, Set<String> days, int col, int row, Map<String, String> ds})>{};
    for (final f in frags) {
      if (_dayRx.hasMatch(f.text.trim()) || _timeRx.hasMatch(f.text)) continue;
      if (f.cx < heads.first.cx - colW * 0.6) continue;
      final y = adj(f);
      var row = 0;
      for (var i = 1; i < rowY.length; i++) {
        if ((y - rowY[i]).abs() < (y - rowY[row]).abs()) row = i;
      }
      if ((y - rowY[row]).abs() > rowH * 0.6) continue;
      final cols = <int>[
        for (var i = 0; i < heads.length; i++)
          if (heads[i].cx >= f.box.left - colW * 0.3 &&
              heads[i].cx <= f.box.right + colW * 0.3)
            i
      ];
      if (cols.isEmpty) continue;
      for (final part in f.text.split('/')) {
        final name = part.trim().replaceAll(RegExp(r'[^A-Za-z0-9 &\-\(\)\.]'), '').trim();
        if (RegExp(r'[A-Za-z]').allMatches(name).length < 3) continue;
        if (_skipRx.hasMatch(name)) continue;
        final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final day = dayName(dayFr[row].text);
        final old = byKey[key];
        final col = cols.reduce(math.min);
        byKey[key] = old == null
            ? (name: name, days: {day}, col: col, row: row, ds: {day: slots[col]})
            : (
                name: old.name,
                ds: {...old.ds, day: old.ds[day] ?? slots[col]},
                days: {...old.days, day},
                col: old.row < row || (old.row == row && old.col <= col)
                    ? old.col
                    : col,
                row: math.min(old.row, row)
              );
      }
    }
    return [
      for (final v in byKey.values)
        (name: v.name, slot: slots[v.col], days: v.days.toList(), daySlots: v.ds),
    ];
  } finally {
    rec.close();
  }
}
