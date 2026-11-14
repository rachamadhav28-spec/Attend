typedef TtEntry = ({String name, String slot, List<String> days, Map<String, String> daySlots});

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
