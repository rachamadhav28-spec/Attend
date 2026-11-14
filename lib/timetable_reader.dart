import 'dart:io';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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

/// Crops dark borders and enlarges small pictures so the text reader can see
/// the letters. Returns the original path if anything goes wrong.
Future<String> _prepare(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    var codec = await instantiateImageCodec(bytes);
    var img = (await codec.getNextFrame()).image;
    if (img.width > 3000) {
      codec = await instantiateImageCodec(bytes, targetWidth: 3000);
      img = (await codec.getNextFrame()).image;
    }
    final w = img.width, h = img.height;
    final ByteData data = (await img.toByteData(format: ImageByteFormat.rawRgba))!;
    bool bright(int x, int y) {
      final i = (y * w + x) * 4;
      return (data.getUint8(i) * 3 + data.getUint8(i + 1) * 6 + data.getUint8(i + 2)) ~/ 10 > 40;
    }

    bool rowOk(int y) {
      var c = 0, n = 0;
      for (var x = 0; x < w; x += 4) {
        n++;
        if (bright(x, y)) c++;
      }
      return c / n > 0.3;
    }

    var top = 0, bottom = h - 1;
    while (top < h - 1 && !rowOk(top)) {
      top++;
    }
    while (bottom > top && !rowOk(bottom)) {
      bottom--;
    }
    bool colOk(int x) {
      var c = 0, n = 0;
      for (var y = top; y <= bottom; y += 4) {
        n++;
        if (bright(x, y)) c++;
      }
      return c / n > 0.3;
    }

    var left = 0, right = w - 1;
    while (left < w - 1 && !colOk(left)) {
      left++;
    }
    while (right > left && !colOk(right)) {
      right--;
    }
    var crop = Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
    if (crop.width < 200 || crop.height < 100) {
      crop = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    }
    final scale = crop.width < 2400 ? (2400 / crop.width).clamp(1.0, 4.0) : 1.0;
    final full = crop.width == w && crop.height == h;
    if (scale == 1.0 && full) return path;
    final ow = (crop.width * scale).round(), oh = (crop.height * scale).round();
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImageRect(img, crop, Rect.fromLTWH(0, 0, ow.toDouble(), oh.toDouble()),
        Paint()..filterQuality = FilterQuality.high);
    final out = await rec.endRecording().toImage(ow, oh);
    final png = await out.toByteData(format: ImageByteFormat.png);
    final f = File('${Directory.systemTemp.path}/tt_prep_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(png!.buffer.asUint8List());
    return f.path;
  } catch (_) {
    return path;
  }
}

/// Reads a grid timetable photo: days down the side, time ranges across the top.
/// Returns [] if no grid is found (caller falls back to plain text lines).
Future<List<TtEntry>> readTimetable(String path, Set<String> allowed) async {
  final rec = TextRecognizer();
  final prepared = await _prepare(path);
  try {
    final out = await rec.processImage(InputImage.fromFilePath(prepared));
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
    final starts = <String>[], ends = <String>[];
    for (final f in heads) {
      final m = _timeRx.firstMatch(f.text)!;
      starts.add(_fmt(int.parse(m.group(1)!), m.group(2)!));
      ends.add(_fmt(int.parse(m.group(3)!), m.group(4)!));
    }
    final slots = [for (var i = 0; i < heads.length; i++) '${starts[i]} - ${ends[i]}'];
    // A column nobody writes in (the lunch column) must not stretch a slot.
    final used = <int>{};
    for (final f in frags) {
      if (_dayRx.hasMatch(f.text.trim()) || _timeRx.hasMatch(f.text)) continue;
      if (RegExp(r'[A-Za-z]').allMatches(f.text).length < 3) continue;
      if (adj(f) < firstDayY - rowH * 0.5) continue;
      for (var i = 0; i < heads.length; i++) {
        if (heads[i].cx >= f.box.left - colW * 0.3 &&
            heads[i].cx <= f.box.right + colW * 0.3) {
          used.add(i);
        }
      }
    }
    int toMin(String s) {
      final m = RegExp(r'(\d+):(\d+) (AM|PM)').firstMatch(s)!;
      var h = int.parse(m[1]!) % 12;
      if (m[3] == 'PM') h += 12;
      return h * 60 + int.parse(m[2]!);
    }
    // Snap to a slot the app knows (same start, closest length).
    String snap(String start, String end, String fallback) {
      if (allowed.contains('$start - $end')) return '$start - $end';
      final s = toMin(start), e = toMin(end);
      String? best;
      var bestD = 1 << 30;
      for (final a in allowed) {
        final p = a.split(' - ');
        if (p.length != 2) continue;
        if (toMin(p[0]) != s) continue;
        final d = (toMin(p[1]) - e).abs();
        if (d < bestD) {
          bestD = d;
          best = a;
        }
      }
      return best ?? fallback;
    }
    String spanFor(List<int> cols) {
      final live = cols.where(used.contains).toList();
      final use = live.isEmpty ? cols : live;
      final a = use.reduce(math.min), b = use.reduce(math.max);
      return snap(starts[a], ends[b], slots[a]);
    }
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
            ? (name: name, days: {day}, col: col, row: row, ds: {day: spanFor(cols)})
            : (
                name: old.name,
                ds: {...old.ds, day: old.ds[day] ?? spanFor(cols)},
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
        (name: v.name, slot: v.ds.values.first, days: v.days.toList(), daySlots: v.ds),
    ];
  } finally {
    rec.close();
    if (prepared != path) {
      try {
        File(prepared).deleteSync();
      } catch (_) {}
    }
  }
}


/// Phone screenshots of a photographed timetable often have big black bars and
/// tiny text. Crop the bright part and enlarge it so the text reader can see it.
/// Returns the original path if anything goes wrong.
Future<String> prepareForOcr(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final img = (await codec.getNextFrame()).image;
    final w = img.width, h = img.height;
    final data = await img.toByteData(format: ImageByteFormat.rawRgba);
    if (data == null) return path;
    double lum(int x, int y) {
      final i = (y * w + x) * 4;
      return 0.3 * data.getUint8(i) +
          0.59 * data.getUint8(i + 1) +
          0.11 * data.getUint8(i + 2);
    }

    // Rows whose average brightness says "paper", not "black bar".
    int top = -1, bottom = -1;
    for (var y = 0; y < h; y++) {
      var sum = 0.0, n = 0;
      for (var x = 0; x < w; x += 6) {
        sum += lum(x, y);
        n++;
      }
      if (sum / n > 70) {
        if (top < 0) top = y;
        bottom = y;
      }
    }
    if (top < 0 || bottom - top < h * 0.15) return path;
    int left = -1, right = -1;
    for (var x = 0; x < w; x++) {
      var sum = 0.0, n = 0;
      for (var y = top; y <= bottom; y += 6) {
        sum += lum(x, y);
        n++;
      }
      if (sum / n > 70) {
        if (left < 0) left = x;
        right = x;
      }
    }
    if (left < 0) {
      left = 0;
      right = w - 1;
    }
    final cw = (right - left + 1).toDouble();
    final ch = (bottom - top + 1).toDouble();
    final scale = (2400 / math.max(cw, ch)).clamp(1.0, 3.0);
    final dw = (cw * scale).round(), dh = (ch * scale).round();
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(left.toDouble(), top.toDouble(), cw, ch),
      Rect.fromLTWH(0, 0, dw.toDouble(), dh.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final out = await rec.endRecording().toImage(dw, dh);
    final png = await out.toByteData(format: ImageByteFormat.png);
    if (png == null) return path;
    final f = File('${Directory.systemTemp.path}/tt_ocr.png');
    await f.writeAsBytes(png.buffer.asUint8List());
    return f.path;
  } catch (_) {
    return path;
  }
}


String _slotTime(String h, String m, String? ap) {
  var hh = int.parse(h);
  final pm = ap != null ? ap.toLowerCase() == 'pm' : (hh == 12 || hh < 7);
  if (hh == 0) hh = 12;
  final h12 = hh > 12 ? hh - 12 : hh;
  return '${h12.toString().padLeft(2, '0')}:$m ${pm ? 'PM' : 'AM'}';
}

int _slotMin(String s) {
  final m = RegExp(r'(\d+):(\d+) (AM|PM)').firstMatch(s)!;
  var h = int.parse(m[1]!) % 12;
  if (m[3] == 'PM') h += 12;
  return h * 60 + int.parse(m[2]!);
}

String _snapSlot(String start, String end, Set<String> allowed) {
  final exact = '$start - $end';
  if (allowed.contains(exact)) return exact;
  final s = _slotMin(start), e = _slotMin(end);
  String? best;
  var bestD = 1 << 30;
  for (final a in allowed) {
    final p = a.split(' - ');
    if (p.length != 2 || _slotMin(p[0]) != s) continue;
    final d = (_slotMin(p[1]) - e).abs();
    if (d < bestD) {
      bestD = d;
      best = a;
    }
  }
  return best ?? exact;
}

/// Reads text like "Maths-I | Mon 11:00 AM-12:00 PM, Tue 12:00 PM-01:00 PM".
List<TtEntry> parseTimetableText(String text, Set<String> allowed) {
  final rx = RegExp(
      r'(mon|tue|wed|thu|fri|sat|sun)[a-z]*\.?\s*[:\-]?\s*(\d{1,2})[:.](\d{2})\s*(am|pm)?\s*(?:-|–|—|to)\s*(\d{1,2})[:.](\d{2})\s*(am|pm)?',
      caseSensitive: false);
  final out = <TtEntry>[];
  for (final raw in text.split('\n')) {
    final bar = raw.indexOf('|');
    if (bar < 0) continue;
    var name = raw
        .substring(0, bar)
        .replaceAll(RegExp(r'[*_`#]'), '')
        .replaceFirst(RegExp(r'^\s*(?:[-•]|\d+[.)])\s*'), '')
        .trim();
    if (name.length < 2) continue;
    final days = <String>[];
    final ds = <String, String>{};
    for (final m in rx.allMatches(raw.substring(bar + 1))) {
      final d = m[1]!.toLowerCase();
      final day = d[0].toUpperCase() + d.substring(1);
      final slot = _snapSlot(_slotTime(m[2]!, m[3]!, m[4]),
          _slotTime(m[5]!, m[6]!, m[7]), allowed);
      if (!days.contains(day)) days.add(day);
      ds.putIfAbsent(day, () => slot);
    }
    if (days.isEmpty) continue;
    out.add((name: name, slot: ds.values.first, days: days, daySlots: ds));
  }
  return out;
}
