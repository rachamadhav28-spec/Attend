import 'package:flutter/material.dart';
import 'ui_kit.dart';

// Source: India holidays 2026-2027 state-wise PDF (Nov 8 2026 - Dec 2027).
// Each row: date, name, state codes ('ALL' = every state), optional restricted flag.
const List<(String, String, String)> kHolidayRows = [
  ('2026-11-08', 'Diwali / Deepavali & Naraka Chaturdasi', 'AN AP AR AS BR CG CH DH DL GA GJ HP HR JH JK KA KL LA MH ML MP MZ NL OR PB PY RJ TN TR TS UK UP WB'),
  ('2026-11-24', 'Guru Nanak Jayanti / Karthika Purnima / Lachit Divas / Guru Tegh Bahadur Martyrdom Day', 'AN AR AS CG CH DL GJ HP HR JH JK LA LD MH MP MZ NL OR PB RJ TS UK UP WB'),
  ('2027-01-01', 'New Year\'s Day', 'AR ML MN MZ NL PY SK TN TS WB'),
  ('2027-01-14', 'Makar Sankranti / Magh Bihu / Bhogi / Uttarayana', 'AN AP AR AS DH GJ JH KA OR SK TS'),
  ('2027-01-26', 'Republic Day & Gwther Bathou San', 'ALL'),
  ('2027-03-06', 'Maha Shivaratri', 'AP BR CG CH DH DL GA GJ HP HR JH JK KA KL LD MH MP OR PB RJ TR TS UK UP WB'),
  ('2027-03-10', 'Ramzan Id / Id-ul-Fitr (tentative)', 'ALL'),
  ('2027-03-11', 'Ramazan (2nd Day)', 'TS'),
  ('2027-04-01', 'Utkal Dibas (Odisha Day) & Annual Closing of Bank Accounts', 'ALL'),
  ('2027-04-05', 'Babu Jagjivan Ram Jayanti', 'AP TS'),
  ('2027-04-07', 'Ugadi / Gudi Padwa / Cheti Chand / Sajibu Cheiraoba', 'AP DH GA GJ JK KA MH MN MP RJ TN TS UK'),
  ('2027-04-08', 'Telugu New Year / Guru Nabha Dass Jayanti / Ugadi', 'PB PY TS'),
  ('2027-04-14', 'Dr. B.R. Ambedkar Jayanti / Vaisakhi / Vishu / Tamil New Year / Bohag Bihu / Maha Vishuba Sankranti', 'AP AS BR CG GA GJ HP HR JH JK KA KL LA MH MN MP OR PB PY RJ SK TN TR TS UK UP WB'),
  ('2027-04-15', 'Rama Navami / Bengali New Year (Pohela Boishakh) / Bohag Bihu / Vishu / Himachal Day', 'AN AP AR AS BR CG CH DL GA GJ HP HR JH JK KL LD MH MP MZ OR PB RJ SK TR TS UK UP WB'),
  ('2027-05-17', 'Bakrid / Id-ul-Zuha (tentative)', 'ALL'),
  ('2027-06-02', 'Telangana State Formation Day', 'TS'),
  ('2027-06-15', 'Raja Sankranti / YMA Day / Muharram (KL, TN, TS)', 'KL MZ OR TN TS'),
  ('2027-06-16', 'Muharram / Ashura (tentative)', 'AN AP AS BR CG DL GJ HP JH JK KA LA LD MH MP MZ OR RJ TR TS UK UP WB'),
  ('2027-08-02', 'Bonalu / Karkidaka Vaavu Bali / Hariyali Amavasya', 'CG KL TS'),
  ('2027-08-15', 'Independence Day, Milad un-Nabi & Parsi New Year', 'ALL'),
  ('2027-08-25', 'Janmashtami / Sri Krishna Astami', 'AP AS BR CG CH DH DL GJ HP HR JH JK LD ML MN MP MZ NL PB RJ SK TN TR TS UK UP WB'),
  ('2027-09-04', 'Ganesh Chaturthi / Vinayaka Chavithi', 'AP DH GA GJ JH KA LD MH OR PY TN TS'),
  ('2027-09-30', 'First Day of Sharad Navratri / Bathukamma Starting Day 2027) Master Schedule Q4 2027 alongside Mahatma Gandhi State Formation Days (November GST Munshi, The Hindu).', 'TS'),
  ('2027-10-02', 'Mahatma Gandhi Jayanti', 'ALL'),
  ('2027-10-07', 'Durga Ashtami / Maha Ashtami', 'AS BR JH OR SK TR TS WB'),
  ('2027-10-09', 'Dussehra (Vijaya Dashami)', 'ALL'),
  ('2027-10-10', 'Vijaya Dasami (TS)', 'TS'),
  ('2027-10-29', 'Diwali / Deepavali / Kali Puja', 'ALL'),
  ('2027-11-14', 'Guru Nanak Jayanti / Kartik Purnima', 'ALL'),
  ('2027-12-25', 'Christmas Day', 'ALL'),
  ('2027-12-26', 'Boxing Day', 'ML MZ NL TS'),
];

/// Central Government gazetted holidays: apply to every state.
const List<(String, String)> kCentralRows = [
  ('2026-11-08', 'Diwali / Deepavali'),
  ('2026-11-24', 'Guru Nanak Jayanti'),
  ('2026-12-25', 'Christmas Day'),
  ('2027-01-26', 'Republic Day'),
  ('2027-03-10', 'Id-ul-Fitr (tentative)'),
  ('2027-03-22', 'Holi'),
  ('2027-03-23', 'Holi'),
  ('2027-03-26', 'Good Friday'),
  ('2027-04-15', 'Rama Navami'),
  ('2027-04-19', 'Mahavir Jayanti'),
  ('2027-05-17', 'Bakrid / Id-ul-Zuha (tentative)'),
  ('2027-05-20', 'Buddha Purnima'),
  ('2027-06-16', 'Muharram (tentative)'),
  ('2027-08-15', 'Independence Day'),
  ('2027-08-15', 'Milad-un-Nabi (tentative)'),
  ('2027-08-25', 'Janmashtami'),
  ('2027-10-02', 'Mahatma Gandhi Jayanti'),
  ('2027-10-09', 'Dussehra (Vijaya Dashami)'),
  ('2027-10-29', 'Diwali / Deepavali'),
  ('2027-11-14', 'Guru Nanak Jayanti'),
  ('2027-12-25', 'Christmas Day'),
];

const Map<String, String> kStates = {
  'Telangana': 'TS',
};

class Holiday {
  final DateTime date;
  final String name;
  const Holiday(this.date, this.name);
}

/// Holidays for a state name (all-India ones included), soonest first.
List<Holiday> holidaysForState(String stateName) {
  const code = 'TS'; // Only Telangana holidays are included.
  final out = <Holiday>[
    for (final c in kCentralRows) Holiday(DateTime.parse(c.$1), c.$2)
  ];
  String first(String n) => n.toLowerCase().split(RegExp(r'[^a-z]+')).first;
  for (final r in kHolidayRows) {
    final all = r.$3 == 'ALL';
    if (!all && !(code != null && r.$3.split(' ').contains(code))) continue;
    // Already covered by the central list on that date (same festival)?
    final dup = kCentralRows.any((c) =>
        c.$1 == r.$1 &&
        (first(c.$2) == first(r.$2) || all));
    if (!dup) out.add(Holiday(DateTime.parse(r.$1), r.$2));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Bottom-sheet state picker. Returns the chosen state name, or null.
Future<String?> pickState(BuildContext context, String current) {
  final names = kStates.keys.toList()..sort();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      builder: (_, scroll) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.line, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text('Choose your state',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: names.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(names[i]),
                trailing: names[i] == current
                    ? Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, names[i]),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Month grid. A dot marks a state holiday; a tinted cell marks a day you
/// marked as holiday yourself.
class HolidayCalendar extends StatefulWidget {
  final DateTime selected;
  final Set<String> stateHolidays; // yyyy-MM-dd
  final Set<String> myHolidays;
  final ValueChanged<DateTime> onSelect;
  const HolidayCalendar({
    super.key,
    required this.selected,
    required this.stateHolidays,
    required this.myHolidays,
    required this.onSelect,
  });

  @override
  State<HolidayCalendar> createState() => _HolidayCalendarState();
}

class _HolidayCalendarState extends State<HolidayCalendar> {
  late DateTime _month =
      DateTime(widget.selected.year, widget.selected.month);

  static const _names = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December'
  ];

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final lead = first.weekday % 7; // Sunday first
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <Widget>[
      for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
        Center(
            child: Text(d,
                style: TextStyle(color: AppColors.muted, fontSize: 13))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var day = 1; day <= count; day++)
        _cell(DateTime(_month.year, _month.month, day)),
    ];
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Center(
                child: Text('${_names[_month.month - 1]} ${_month.year}',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            IconButton(
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        for (var r = 0; r * 7 < cells.length; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: r * 7 + c < cells.length
                        ? cells[r * 7 + c]
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(DateTime d) {
    final k = _key(d);
    final sel = _key(widget.selected) == k;
    final state = widget.stateHolidays.contains(k);
    final mine = widget.myHolidays.contains(k);
    return GestureDetector(
      onTap: () => widget.onSelect(d),
      child: AnimatedContainer(
        duration: kFast,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.primary
              : (mine ? AppColors.tint : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${d.day}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    color: sel ? Colors.white : AppColors.ink)),
            const SizedBox(height: 1),
            if (state)
              Image.asset('assets/holiday.png',
                width: 14,
                height: 14,
                color: sel ? Colors.white : AppColors.primary)
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
