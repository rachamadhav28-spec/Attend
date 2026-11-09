import 'package:flutter/material.dart';
import 'ui_kit.dart';

// Source: India holidays 2026-2027 state-wise PDF (Nov 8 2026 - Dec 2027).
// Each row: date, name, state codes ('ALL' = every state), optional restricted flag.
const List<(String, String, String)> kHolidayRows = [
  ('2026-11-08', 'Diwali / Deepavali & Naraka Chaturdasi', 'AN AP AR AS BR CG CH DH DL GA GJ HP HR JH JK KA KL LA MH ML MP MZ NL OR PB PY RJ TN TR TS UK UP WB'),
  ('2026-11-09', 'Govardhan Puja / Balipadyami / Laxmi Puja / Deepavali Holiday', 'CG CH DH GJ HR JH MN MP PB PY RJ SK TN TR UP WB'),
  ('2026-11-10', 'Balipadyami Diwali / Vikram Samvat / Bhai Duj / Kali Puja', 'BR GJ KA MH SK UK WB'),
  ('2026-11-11', 'Bhai Duj / Chitragupt Jayanti / Ningol Chakkouba / Laxmi Puja', 'AS GJ HP JH MN RJ SK UP WB'),
  ('2026-11-12', 'Day after Bhatridwitya', 'WB'),
  ('2026-11-13', 'Wangala Festival', 'ML'),
  ('2026-11-15', 'Chhat Puja (Pratihar Sashthi) & Birsa Munda Jayanti', 'AS BR CG DH JH MP WB'),
  ('2026-11-16', 'Chhath Puja Holiday / Shahidi Divas S. Kartar Singh Sarabha Ji', 'BR DL JH PB WB'),
  ('2026-11-20', 'Igas-Bagwal', 'UK'),
  ('2026-11-23', 'Seng Kut Snem', 'ML'),
  ('2026-11-24', 'Guru Nanak Jayanti / Karthika Purnima / Lachit Divas / Guru Tegh Bahadur Martyrdom Day', 'AN AR AS CG CH DL GJ HP HR JH JK LA LD MH MP MZ NL OR PB RJ TS UK UP WB'),
  ('2026-11-27', 'Kanakadasa Jayanti', 'KA'),
  ('2026-11-30', 'Sakewa', 'SK'),
  ('2026-12-01', 'State Inauguration Day / Indigenous Faith Day', 'AR NL'),
  ('2026-12-02', 'Asom Divas (Su-Ka-Pha Divas)', 'AS'),
  ('2026-12-03', 'Feast of St. Francis Xavier / World Disabled Day', 'GA TR'),
  ('2026-12-07', 'Kagyed Dance', 'SK'),
  ('2026-12-09', 'Losar / Losoong / Namsoong', 'LA SK'),
  ('2026-12-10', 'Losar / Losoong / Namsoong', 'LA SK'),
  ('2026-12-11', 'Losar / Losoong / Namsoong', 'LA SK'),
  ('2026-12-12', 'Death Anniversary of Pa Togan Nengminja Sangma / Nupi Lal / Losoong', 'ML MN SK'),
  ('2026-12-13', 'Losoong / Namsoong', 'SK'),
  ('2026-12-14', 'Martyrdom Day of Sri Guru Teg Bahadur Ji / Losoong', 'PB SK'),
  ('2026-12-15', 'Nyempa Guzom / Chasok Tangnam', 'SK'),
  ('2026-12-16', 'Nyempa Guzom / Chasok Tangnam', 'SK'),
  ('2026-12-18', 'Guru Ghasidas Jayanti / Death Anniversary of U SoSo Tham', 'CG ML'),
  ('2026-12-19', 'Goa Liberation Day', 'GA'),
  ('2027-01-01', 'New Year\'s Day', 'AR ML MN MZ NL PY SK TN TS WB'),
  ('2027-01-02', 'Mannam Jayanti / New Year Celebration', 'KL MZ'),
  ('2027-01-06', 'Mairaj-ul-Alam & Friday following Shab-i-Miraj', 'JK'),
  ('2027-01-08', 'Mairaj-ul-Alam & Friday following Shab-i-Miraj', 'JK'),
  ('2027-01-09', 'Death Anniversary of Maharaja Gambhir Singh', 'MN'),
  ('2027-01-11', 'Missionary Day', 'MZ'),
  ('2027-01-12', 'Swami Vivekananda Jayanti', 'WB'),
  ('2027-01-13', 'Lohri / Sohrai', 'JH JK'),
  ('2027-01-14', 'Makar Sankranti / Magh Bihu / Bhogi / Uttarayana', 'AN AP AR AS DH GJ JH KA OR SK TS'),
  ('2027-01-15', 'Pongal / Guru Gobind Singh Jayanti', 'AP BR CH HR JK PB PY RJ TN TR UK'),
  ('2027-01-16', 'Thiruvalluvar Day / Mattu Pongal / Kanuma Panduga / Tusu Puja', 'AP AS PY TN'),
  ('2027-01-17', 'Uzhavar Thirunal', 'TN'),
  ('2027-01-19', 'Imoinu Iratpa (Jan 19) / Gaan-Ngai (Jan 20)', 'MN'),
  ('2027-01-20', 'Imoinu Iratpa (Jan 19) / Gaan-Ngai (Jan 20)', 'MN'),
  ('2027-01-22', 'Thaipoosam / Cherchhera', 'CG TN'),
  ('2027-01-23', 'Netaji Subhas Chandra Bose Jayanti', 'AS JH OR TR WB'),
  ('2027-01-24', 'Shab-e-Barat', 'BR WB'),
  ('2027-01-25', 'Statehood Day', 'HP'),
  ('2027-01-26', 'Republic Day & Gwther Bathou San', 'ALL'),
  ('2027-01-31', 'Me-Dam-Me- Phi', 'AS'),
  ('2027-02-05', 'Mela Dosmochey', 'LA'),
  ('2027-02-07', 'Sonam Lochhar / Losar', 'SK'),
  ('2027-02-10', 'Day before Saraswati Puja', 'WB'),
  ('2027-02-11', 'Vasant Panchami / Saraswati Puja / Sir Chhotu Ram Jayanti', 'BR HR OR TR WB'),
  ('2027-02-13', 'Shree Devnarayan Jayanti', 'RJ'),
  ('2027-02-14', 'Thakur Panchanan Barma Birthday', 'WB'),
  ('2027-02-15', 'Lui-Ngai-Ni', 'MN'),
  ('2027-02-19', 'Chhatrapati Shivaji Maharaj Jayanti', 'MH'),
  ('2027-02-20', 'Guru Ravidas Jayanti / Statehood Day (AR, MZ) / Bir Chilarai Divas / Bhumchu', 'AR AS BR CG HP HR JH JK MP MZ PB SK WB'),
  ('2027-02-26', 'Akhil Sikkim Khas Chettri Bahun Kalyan Sangh Foundation Day', 'SK'),
  ('2027-03-05', 'Jamat Ul-Vida / Chapchar Kut', 'JK MZ'),
  ('2027-03-06', 'Maha Shivaratri', 'AP BR CG CH DH DL GA GJ HP HR JH JK KA KL LD MH MP OR PB RJ TR TS UK UP WB'),
  ('2027-03-07', 'Shab-i-Qadr', 'JK'),
  ('2027-03-09', 'Day before Ramazan / Id-ul-Fitr', 'PY WB'),
  ('2027-03-10', 'Ramzan Id / Id-ul-Fitr (tentative)', 'ALL'),
  ('2027-03-11', 'Ramazan (2nd Day)', 'TS'),
  ('2027-03-21', 'Nauroz', 'JK LA'),
  ('2027-04-01', 'Utkal Dibas (Odisha Day) & Annual Closing of Bank Accounts', 'ALL'),
  ('2027-04-02', 'Bhakt Mata Karma Jayanti', 'CG'),
  ('2027-04-04', 'Shri Harichand Thakur Jayanti', 'WB'),
  ('2027-04-05', 'Babu Jagjivan Ram Jayanti', 'AP TS'),
  ('2027-04-07', 'Ugadi / Gudi Padwa / Cheti Chand / Sajibu Cheiraoba', 'AP DH GA GJ JK KA MH MN MP RJ TN TS UK'),
  ('2027-04-08', 'Telugu New Year / Guru Nabha Dass Jayanti / Ugadi', 'PB PY TS'),
  ('2027-04-09', 'Sarhul & Sarhul Holiday', 'JH'),
  ('2027-04-10', 'Sarhul & Sarhul Holiday', 'JH'),
  ('2027-04-11', 'Mahatma Jyotiba Phule Jayanti', 'RJ'),
  ('2027-04-14', 'Dr. B.R. Ambedkar Jayanti / Vaisakhi / Vishu / Tamil New Year / Bohag Bihu / Maha Vishuba Sankranti', 'AP AS BR CG GA GJ HP HR JH JK KA KL LA MH MN MP OR PB PY RJ SK TN TR TS UK UP WB'),
  ('2027-04-15', 'Rama Navami / Bengali New Year (Pohela Boishakh) / Bohag Bihu / Vishu / Himachal Day', 'AN AP AR AS BR CG CH DL GA GJ HP HR JH JK KL LD MH MP MZ OR PB RJ SK TR TS UK UP WB'),
  ('2027-04-16', 'Bohag Bihu / Vishu 2nd Day', 'AS PY'),
  ('2027-04-19', 'Mahavir Jayanti', 'BR CG CH DH DL GJ HR JH KA MH MP MZ PB RJ TN UK UP WB'),
  ('2027-04-21', 'Garia Puja / Sati Sadhani Divas', 'AS TR'),
  ('2027-04-23', 'Veer Kunwar Singh Jayanti / Khongjom Day', 'BR MN'),
  ('2027-05-01', 'May Day (Labour Day) / Maharashtra Din / Gujarat Day', 'AN AP AS BR DH GA GJ JH KA KL MH MN PB PY TN TR WB'),
  ('2027-05-06', 'Tithi of Damodardeva', 'AS'),
  ('2027-05-08', 'Maharshi Parasuram Jayanti', 'GJ HP HR MP PB RJ'),
  ('2027-05-09', 'Rabindranath Tagore Jayanti & Basava Jayanti', 'KA TR WB'),
  ('2027-05-13', 'Urs Shah-I-Hamdan Sahib', 'JK'),
  ('2027-05-14', 'Janaki Navami', 'BR'),
  ('2027-05-16', 'Sikkim State Day & Bakri Id Eve', 'PY SK'),
  ('2027-05-17', 'Bakrid / Id-ul-Zuha (tentative)', 'ALL'),
  ('2027-05-18', 'Eid-ul-Azha Holiday', 'JK'),
  ('2027-05-20', 'Buddha Purnima', 'AN AR AS BR CG CH DL HP HR JH JK LA LD MH MP MZ OR SK TR UK UP WB'),
  ('2027-05-21', 'Janmotsav of Sri Sri Madhabdeva', 'AS'),
  ('2027-05-25', 'Eid-e-Ghadeer (May 25) / Birthday of Kazi Nazrul Islam (May 26)', 'LA TR'),
  ('2027-05-26', 'Eid-e-Ghadeer (May 25) / Birthday of Kazi Nazrul Islam (May 26)', 'LA TR'),
  ('2027-05-30', 'Goa Statehood Day', 'GA'),
  ('2027-06-02', 'Telangana State Formation Day', 'TS'),
  ('2027-06-04', 'Sabitri Amavasya', 'OR'),
  ('2027-06-07', 'Maharana Pratap Jayanti', 'HP HR MP RJ'),
  ('2027-06-08', 'Martyrdom Day of Sri Guru Arjun Dev Ji', 'PB'),
  ('2027-06-11', 'Mela Khir Bhawani', 'JK'),
  ('2027-06-14', 'Pahili Raja', 'OR'),
  ('2027-06-15', 'Raja Sankranti / YMA Day / Muharram (KL, TN, TS)', 'KL MZ OR TN TS'),
  ('2027-06-16', 'Muharram / Ashura (tentative)', 'AN AP AS BR CG DL GJ HP JH JK KA LA LD MH MP MZ OR RJ TR TS UK UP WB'),
  ('2027-06-18', 'Kabir Jayanti / Saga Dawa', 'BR CG HP HR PB SK'),
  ('2027-07-01', 'Doctors\' Day (Half-Day Regional Holiday)', 'WB'),
  ('2027-07-05', 'Rath Yatra / Kang / MHIP Day', 'JH MN MZ OR WB'),
  ('2027-07-06', 'Rath Yatra / Kang / MHIP Day', 'JH MN MZ OR WB'),
  ('2027-07-11', 'Kharchi Puja', 'TR'),
  ('2027-07-13', 'Bhanu Jayanti / Hemis Tsechu', 'LA SK'),
  ('2027-07-16', 'Harela', 'UK'),
  ('2027-07-17', 'Death Anniversary of U Tirot Sing', 'ML'),
  ('2027-07-25', 'Chehlum', 'BR'),
  ('2027-07-28', 'Ker Puja', 'TR'),
  ('2027-07-31', 'Martyrdom Day of Shahid Udham Singh', 'HR PB'),
  ('2027-08-02', 'Bonalu / Karkidaka Vaavu Bali / Hariyali Amavasya', 'CG KL TS'),
  ('2027-08-06', 'Drukpa Tshechi', 'SK'),
  ('2027-08-08', 'Tendong Lho Rum Faat', 'SK'),
  ('2027-08-09', 'Vishwa Adivasi Diwas (World Tribal Day)', 'CG JH RJ'),
  ('2027-08-11', 'Guru Rimpoche Thungkar Tshechu', 'SK'),
  ('2027-08-13', 'Patriot\'s Day / Varalakshmi Vratham', 'AP MN'),
  ('2027-08-14', 'Milad-un-Nabi (Kerala)', 'KL'),
  ('2027-08-15', 'Independence Day, Milad un-Nabi & Parsi New Year', 'ALL'),
  ('2027-08-16', 'De Jure Transfer Day / Parsi New Year (Shahenshahi Bank Holiday)', 'MH PY'),
  ('2027-08-17', 'Raksha Bandhan / Jhulana Purnima', 'CG DH GJ HP HR JH LD MP OR RJ UK UP WB'),
  ('2027-08-19', 'Birthday of Maharaja Bir Bikram Kishore Manikya', 'TR'),
  ('2027-08-20', 'Friday Following Eid-i-Milad / Nepali Bhasa Manyata Diwas', 'JK SK'),
  ('2027-08-22', 'Tirobhab Tithi of Sri Sri Madhabdeva', 'AS'),
  ('2027-08-24', 'Janmashtami (First Day)', 'KL OR'),
  ('2027-08-25', 'Janmashtami / Sri Krishna Astami', 'AP AS BR CG CH DH DL GJ HP HR JH JK LD ML MN MP MZ NL PB RJ SK TN TR TS UK UP WB'),
  ('2027-08-28', 'Ayyankali Jayanti', 'KL'),
  ('2027-09-02', 'Tirubhav Tithi of Shrimanta Shankar Deva', 'AS'),
  ('2027-09-03', 'Hartalika Teej', 'CG SK'),
  ('2027-09-04', 'Ganesh Chaturthi / Vinayaka Chavithi', 'AP DH GA GJ JH KA LD MH OR PY TN TS'),
  ('2027-09-05', 'Nuakhai & Ganesh Chaturthi (2nd Day)', 'GA OR'),
  ('2027-09-06', 'Day after Nuakhai', 'OR'),
  ('2027-09-10', 'Ramdev Jayanti & Teja Dashmi', 'RJ'),
  ('2027-09-11', 'First Onam / Karma Puja / Karam Puja', 'AS JH KL PY WB'),
  ('2027-09-12', 'Onam (Thiruonam)', 'AN KL LD PY'),
  ('2027-09-13', 'Third Onam (Sep 13) & Fourth Onam (Sep 14)', 'KL'),
  ('2027-09-14', 'Third Onam (Sep 13) & Fourth Onam (Sep 14)', 'KL'),
  ('2027-09-15', 'Sree Narayana Guru Jayanthi / Indrajatra / Pang Lhabsol', 'KL SK'),
  ('2027-09-17', 'Vishwakarma Puja', 'JH UK'),
  ('2027-09-22', 'Sree Narayana Guru Samadhi Day', 'KL'),
  ('2027-09-23', 'Haryana Veer & Shahidi Divas / Maharaja Hari Singh Jayanti', 'HR JK'),
  ('2027-09-30', 'First Day of Sharad Navratri / Bathukamma Starting Day 2027) Master Schedule Q4 2027 alongside Mahatma Gandhi State Formation Days (November GST Munshi, The Hindu).', 'TS'),
  ('2027-10-02', 'Mahatma Gandhi Jayanti', 'ALL'),
  ('2027-10-06', 'Durga Puja (Maha Saptami)', 'AS OR TR WB'),
  ('2027-10-07', 'Durga Ashtami / Maha Ashtami', 'AS BR JH OR SK TR TS WB'),
  ('2027-10-08', 'Maha Navami / Ayudha Poojai', 'AS BR JH KA KL OR PY SK TN TR UP WB'),
  ('2027-10-09', 'Dussehra (Vijaya Dashami)', 'ALL'),
  ('2027-10-10', 'Vijaya Dasami (TS)', 'TS'),
  ('2027-10-15', 'Maharishi Valmiki Jayanti', 'CH DL HP HR KA MP PB'),
  ('2027-10-18', 'Karaka Chaturthi (Karwa Chauth)', 'HP UK'),
  ('2027-10-28', 'Naraka Chaturdasi / Deepavali (South)', 'GA KA KL PY TN'),
  ('2027-10-29', 'Diwali / Deepavali / Kali Puja', 'ALL'),
  ('2027-10-30', 'Govardhan Puja / Bali Pratipada / Vikram Samvat New Year', 'GJ KA MH RJ SK UK UP'),
  ('2027-11-01', 'State Formation Day (Karnataka Rajyotsava / Kerala Piravi / Haryana Day)', 'AP CG HR KA KL PY'),
  ('2027-11-04', 'Chhath Puja (Pratihar Sashthi / Surya Sashthi)', 'BR DL JH WB'),
  ('2027-11-14', 'Guru Nanak Jayanti / Kartik Purnima', 'ALL'),
  ('2027-11-24', 'Guru Tegh Bahadur\'s Martyrdom Day', 'CH HR PB UK UP'),
  ('2027-12-01', 'State Inauguration Day / Indigenous Faith Day', 'AR NL'),
  ('2027-12-03', 'Feast of St. Francis Xavier', 'GA'),
  ('2027-12-19', 'Goa Liberation Day', 'GA'),
  ('2027-12-24', 'Christmas Eve', 'ML MZ NL'),
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
  'Andaman & Nicobar Islands': 'AN',
  'Andhra Pradesh': 'AP',
  'Arunachal Pradesh': 'AR',
  'Assam': 'AS',
  'Bihar': 'BR',
  'Chandigarh': 'CH',
  'Chhattisgarh': 'CG',
  'Dadra & Nagar Haveli and Daman & Diu': 'DH',
  'Delhi': 'DL',
  'Goa': 'GA',
  'Gujarat': 'GJ',
  'Haryana': 'HR',
  'Himachal Pradesh': 'HP',
  'Jammu & Kashmir': 'JK',
  'Jharkhand': 'JH',
  'Karnataka': 'KA',
  'Kerala': 'KL',
  'Ladakh': 'LA',
  'Lakshadweep': 'LD',
  'Madhya Pradesh': 'MP',
  'Maharashtra': 'MH',
  'Manipur': 'MN',
  'Meghalaya': 'ML',
  'Mizoram': 'MZ',
  'Nagaland': 'NL',
  'Odisha': 'OR',
  'Puducherry': 'PY',
  'Punjab': 'PB',
  'Rajasthan': 'RJ',
  'Sikkim': 'SK',
  'Tamil Nadu': 'TN',
  'Telangana': 'TS',
  'Tripura': 'TR',
  'Uttar Pradesh': 'UP',
  'Uttarakhand': 'UK',
  'West Bengal': 'WB',
};

class Holiday {
  final DateTime date;
  final String name;
  const Holiday(this.date, this.name);
}

/// Holidays for a state name (all-India ones included), soonest first.
List<Holiday> holidaysForState(String stateName) {
  final code = kStates[stateName];
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
