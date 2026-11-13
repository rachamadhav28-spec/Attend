import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'splash.dart';
import 'holidays.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:qr/qr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_kit.dart';

// ============================================================================
// PASTE YOUR SUPABASE KEYS HERE (or share them with me and I will fill them in)
// ============================================================================
const String kSupabaseUrl = 'https://carzbtnhfkunhluqsxyf.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_zrT2FIjN9NtqQ6bHMfZczQ_uN8Tnd1W';
/// Web OAuth client ID from Google Cloud (the same one given to Supabase).
/// When set, sign-in happens inside the app with Google's account sheet.
const String kGoogleWebClientId =
    '597428007987-l9933533e9v3ibri8btllvdkki0gniuj.apps.googleusercontent.com';
const String kAuthRedirectUri = 'io.supabase.attendtrack://login-callback/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadPalette();
  if (kSupabaseUrl.startsWith('http') && !kSupabaseAnonKey.startsWith('PASTE_')) {
    try {
      await Supabase.initialize(
        url: kSupabaseUrl,
        anonKey: kSupabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase init error: $e');
    }
  }
  runApp(const AttendTrackApp());
}

class AttendTrackApp extends StatelessWidget {
  const AttendTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttendTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppEntry(),
    );
  }
}

class AttendanceAppLogo extends StatelessWidget {
  final double size;
  const AttendanceAppLogo({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: LogoPainter(1, 1)));
}

/// How many one-hour classes a slot like "02:00 PM - 05:00 PM" holds (min 1).
int slotHours(String slot) {
  final r = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)\s*-\s*(\d{1,2}):(\d{2})\s*(AM|PM)',
          caseSensitive: false)
      .firstMatch(slot);
  if (r == null) return 1;
  int mins(String h, String mm, String ap) {
    var hh = int.parse(h) % 12;
    if (ap.toUpperCase() == 'PM') hh += 12;
    return hh * 60 + int.parse(mm);
  }
  final s = mins(r[1]!, r[2]!, r[3]!);
  final e = mins(r[4]!, r[5]!, r[6]!);
  final d = e - s;
  if (d <= 0) return 1;
  final h = (d / 60).round();
  return h < 1 ? 1 : h;
}

const kTimeSlots = [
  // Single-hour slots
  '10:00 AM - 11:00 AM',
  '11:00 AM - 12:00 PM',
  '12:00 PM - 01:00 PM',
  '02:00 PM - 03:00 PM',
  '03:00 PM - 04:00 PM',
  '04:00 PM - 05:00 PM',
  // Double slots
  '10:00 AM - 12:00 PM',
  '11:00 AM - 01:00 PM',
  '01:00 PM - 03:00 PM',
  '02:00 PM - 05:00 PM',
  '10:00 AM - 01:00 PM',
  '02:00 PM - 05:00 PM',
];

class SubjectModel {
  String name;
  int attendedHours;
  int totalHours;
  String scheduleSlot;
  List<String> days;
  Map<String, String> daySlots;

  String slotFor(String day) => daySlots[day] ?? scheduleSlot;

  SubjectModel({
    required this.name,
    this.attendedHours = 0,
    this.totalHours = 0,
    this.scheduleSlot = '09:30 AM - 10:30 AM',
    List<String>? days,
    Map<String, String>? daySlots,
  })  : days = days ?? ['Mon', 'Wed', 'Fri'],
        daySlots = daySlots ?? {};

  double get percentage =>
      totalHours == 0 ? 100.0 : (attendedHours / totalHours) * 100.0;

  int get safeBunks {
    if (totalHours == 0 || percentage < 75.0) return 0;
    return (attendedHours / 0.75 - totalHours).floor();
  }

  int get classesNeededFor75 {
    if (totalHours == 0 || percentage >= 75.0) return 0;
    final needed = (3 * totalHours) - (4 * attendedHours);
    return needed > 0 ? needed : 1;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'attendedHours': attendedHours,
        'totalHours': totalHours,
        'scheduleSlot': scheduleSlot,
        'days': days,
        'daySlots': daySlots,
      };

  factory SubjectModel.fromJson(Map<String, dynamic> json) => SubjectModel(
        name: json['name'] ?? '',
        attendedHours: json['attendedHours'] ?? 0,
        totalHours: json['totalHours'] ?? 0,
        scheduleSlot: json['scheduleSlot'] ?? '09:30 AM - 10:30 AM',
        days: json['days'] != null
            ? List<String>.from(json['days'])
            : ['Mon', 'Wed', 'Fri'],
        daySlots: json['daySlots'] != null
            ? Map<String, String>.from(json['daySlots'])
            : null,
      );
}

class AttendanceLogItem {
  final String id;
  final String subject;
  final bool present;
  final int hours;
  final String dateKey;
  final String timeStr;
  final String slot;

  AttendanceLogItem({
    required this.id,
    required this.subject,
    required this.present,
    required this.hours,
    required this.dateKey,
    required this.timeStr,
    this.slot = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'present': present,
        'hours': hours,
        'dateKey': dateKey,
        'timeStr': timeStr,
        'slot': slot,
      };

  factory AttendanceLogItem.fromJson(Map<String, dynamic> json) =>
      AttendanceLogItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        subject: json['subject'] ?? '',
        present: json['present'] ?? true,
        hours: json['hours'] ?? 1,
        dateKey: json['dateKey'] ??
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
        timeStr: json['timeStr'] ?? '',
        slot: json['slot'] ?? '',
      );
}

class CloudUser {
  final String? email;
  final String id;
  const CloudUser(this.email, this.id);
}

class CloudBackupService {
  static bool get _isConfigured =>
      kSupabaseUrl.startsWith('http') && !kSupabaseAnonKey.startsWith('PASTE_');

  static SupabaseClient? get _client {
    if (!_isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static CloudUser? get user {
    final u = _client?.auth.currentUser;
    if (u == null) return null;
    return CloudUser(u.email, u.id);
  }

  static String lastError = '';

  static String? sessionJson() {
    try {
      final s = _client?.auth.currentSession;
      return s == null ? null : jsonEncode(s.toJson());
    } catch (_) {
      return null;
    }
  }

  /// Re-opens a saved session without asking Google. Null if it expired.
  static Future<CloudUser?> recover(String json) async {
    try {
      final r = await _client?.auth.recoverSession(json);
      final u = r?.user ?? _client?.auth.currentUser;
      return u == null ? null : CloudUser(u.email, u.id);
    } catch (_) {
      return null;
    }
  }

  static Future<CloudUser?> signInWithGoogle({bool fresh = true}) async {
    final client = _client;
    if (client == null) {
      lastError = 'Supabase URL & Key are not configured in lib/main.dart yet.';
      return null;
    }
    try {
      final current = client.auth.currentUser;
      if (current != null) {
        if (!fresh) return CloudUser(current.email, current.id);
        // Forget the saved session so Google shows the account picker.
        await client.auth.signOut(scope: SignOutScope.local);
      }

      if (!kGoogleWebClientId.startsWith('PASTE_')) {
        final g = GoogleSignIn(
            serverClientId: kGoogleWebClientId, scopes: const ['email']);
        try {
          await g.signOut(); // forget the last account so the sheet shows
        } catch (_) {}
        final acc = await g.signIn();
        if (acc == null) {
          lastError = 'Sign-in cancelled.';
          return null;
        }
        final ga = await acc.authentication;
        if (ga.idToken == null) {
          lastError = 'Google did not return an ID token. Check the Web client ID.';
          return null;
        }
        final res = await client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: ga.idToken!,
          accessToken: ga.accessToken,
        );
        final su = res.user;
        if (su == null) {
          lastError = 'Supabase did not return a user.';
          return null;
        }
        return CloudUser(su.email, su.id);
      }

      final completer = Completer<CloudUser?>();
      late final StreamSubscription<AuthState> sub;
      sub = client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null && !completer.isCompleted) {
          completer.complete(CloudUser(session.user.email, session.user.id));
          sub.cancel();
        }
      });

      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kAuthRedirectUri,
        queryParams: const {'prompt': 'select_account'},
      );

      final result = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          sub.cancel();
          lastError = 'Sign-in timed out or was cancelled.';
          return null;
        },
      );
      return result;
    } catch (e) {
      lastError = e.toString();
      if (lastError.contains('sign_in_failed') &&
          RegExp(r'\b10\b').hasMatch(lastError)) {
        lastError = 'Google rejected this build (error 10). The Android '
            'client in Google Cloud must use package com.madhav.attendtrack '
            'and SHA-1 1A:10:EF:5A:EE:24:39:C7:32:EF:CB:55:E5:6F:96:A3:B1:D2:55:F3. '
            '[$e]';
      }
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _client?.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    try {
      if (!kGoogleWebClientId.startsWith('PASTE_')) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {}
  }

  /// Deletes this account's cloud backup. Needs the delete policy in
  /// SUPABASE_SETUP.sql.
  static Future<bool> deleteBackup() async {
    final c = _client;
    final u = c?.auth.currentUser;
    if (c == null || u == null) return false;
    try {
      await c.from('user_backups').delete().eq('user_id', u.id);
      return true;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  static Future<bool> syncUserToFirestore({
    required String email,
    required String userName,
    required String course,
    required String year,
    required String timetableFileName,
    required List<SubjectModel> subjects,
    required List<String> holidays,
    required List<AttendanceLogItem> historyLogs,
    String state = '',
    String holidayNames = '{}',
    List<String> hiddenHols = const [],
  }) async {
    final client = _client;
    final u = client?.auth.currentUser;
    if (client == null || u == null) {
      lastError = 'Not signed in with Google.';
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final st = state.isNotEmpty ? state : (prefs.getString('state') ?? '');
      final hn = holidayNames != '{}'
          ? holidayNames
          : (prefs.getString('holiday_names') ?? '{}');
      final hh = hiddenHols.isNotEmpty
          ? hiddenHols
          : (prefs.getStringList('hidden_hols') ?? const []);

      await client.from('user_backups').upsert({
        'user_id': u.id,
        'email': u.email ?? email,
        'user_name': userName,
        'course': course,
        'year': year,
        'state': st,
        'holiday_names': hn,
        'hidden_hols': hh,
        'timetable_file_name': timetableFileName,
        'subjects': subjects.map((s) => s.toJson()).toList(),
        'holidays': holidays,
        'history_logs': historyLogs.map((l) => l.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('Supabase backup sync error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> restoreUserFromFirestore() async {
    final client = _client;
    final u = client?.auth.currentUser;
    lastError = '';
    if (client == null || u == null) {
      lastError = 'Not signed in with Google.';
      return null;
    }
    try {
      final row = await client
          .from('user_backups')
          .select()
          .eq('user_id', u.id)
          .maybeSingle();
      if (row == null) return null;
      return {
        'userName': row['user_name'] ?? 'Student',
        'course': row['course'] ?? 'B.Tech',
        'year': row['year'] ?? '2nd Year',
        'state': row['state'] ?? '',
        'holidayNames': row['holiday_names'] ?? '{}',
        'hiddenHols': row['hidden_hols'] ?? const [],
        'timetableFileName': row['timetable_file_name'] ?? 'Restored from Cloud',
        'subjects': row['subjects'],
        'holidays': row['holidays'],
        'historyLogs': row['history_logs'],
      };
    } catch (e) {
      lastError = e.toString();
      debugPrint('Supabase restore error: $e');
      return null;
    }
  }
}

/// Keeps each Google account's attendance data separate on this phone.
class AccountStore {
  static const _keys = [
    'user_name', 'user_email', 'course', 'year', 'state', 'timetable_file',
    'last_cloud_backup', 'subjects', 'holidays', 'history_logs_v2',
    'holiday_names', 'hidden_hols', 'is_onboarded',
  ];

  static Future<List<Map<String, dynamic>>> list() async {
    final p = await SharedPreferences.getInstance();
    try {
      return (jsonDecode(p.getString('accounts') ?? '[]') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> register(String id, String email) async {
    final p = await SharedPreferences.getInstance();
    final l = await list();
    if (!l.any((a) => a['id'] == id)) l.add({'id': id, 'email': email});
    await p.setString('accounts', jsonEncode(l));
  }

  static Future<void> saveSession(String id) async {
    final j = CloudBackupService.sessionJson();
    if (j == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('acct_sess_$id', j);
  }

  static Future<String?> sessionFor(String id) async =>
      (await SharedPreferences.getInstance()).getString('acct_sess_$id');

  static Future<void> remove(String id) async {
    final p = await SharedPreferences.getInstance();
    final l = await list();
    l.removeWhere((a) => a['id'] == id);
    await p.setString('accounts', jsonEncode(l));
    await p.remove('acct_data_$id');
    await p.remove('acct_sess_$id');
  }

  static Future<void> snapshot(String id) async {
    final p = await SharedPreferences.getInstance();
    final snap = <String, dynamic>{
      for (final k in _keys)
        if (p.get(k) != null) k: p.get(k),
    };
    await p.setString('acct_data_$id', jsonEncode(snap));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final k in _keys) {
      await p.remove(k);
    }
  }

  /// Loads a saved copy of this account's data. False if there is none.
  static Future<bool> restore(String id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('acct_data_$id');
    if (raw == null) return false;
    await clear();
    final snap = jsonDecode(raw) as Map<String, dynamic>;
    for (final e in snap.entries) {
      final v = e.value;
      if (v is bool) {
        await p.setBool(e.key, v);
      } else if (v is List) {
        await p.setStringList(e.key, List<String>.from(v));
      } else if (v is String) {
        await p.setString(e.key, v);
      }
    }
    return true;
  }

  /// Writes a cloud backup into local storage (after clear()).
  static Future<void> applyCloud(Map<String, dynamic> data, String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('user_name', data['userName'] ?? 'Student');
    await p.setString('user_email', email);
    await p.setString('course', data['course'] ?? 'B.Tech');
    await p.setString('year', data['year'] ?? '2nd Year');
    await p.setString('state', data['state'] ?? '');
    await p.setString('holiday_names', data['holidayNames'] ?? '{}');
    await p.setStringList(
        'hidden_hols', List<String>.from(data['hiddenHols'] ?? const []));
    await p.setString(
        'timetable_file', data['timetableFileName'] ?? 'Restored from Cloud');
    if (data['holidays'] != null) {
      await p.setStringList('holidays', List<String>.from(data['holidays']));
    }
    if (data['subjects'] != null) {
      await p.setString('subjects', jsonEncode(data['subjects']));
    }
    if (data['historyLogs'] != null) {
      await p.setString('history_logs_v2', jsonEncode(data['historyLogs']));
    }
    await p.setBool('is_onboarded', true);
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kMed,
      child: _splashDone
          ? const RootFlowController(key: ValueKey('root'))
          : SplashScreen(
              key: const ValueKey('splash'),
              onDone: () {
                if (mounted) setState(() => _splashDone = true);
              }),
    );
  }
}

class RootFlowController extends StatefulWidget {
  const RootFlowController({super.key});

  @override
  State<RootFlowController> createState() => _RootFlowControllerState();
}

class _RootFlowControllerState extends State<RootFlowController> {
  bool _loading = true;
  bool _isOnboarded = false;
  int _initialDashboardTab = 0;

  @override
  void initState() {
    super.initState();
    _checkState();
  }

  Future<void> _checkState() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('is_onboarded') ?? false;
    setState(() {
      _isOnboarded = onboarded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isOnboarded) {
      return InitialStudentSetupScreen(
        onCompletedOpenProfile: () {
          setState(() {
            _isOnboarded = true;
            _initialDashboardTab = 4;
          });
        },
      );
    }
    return MainDashboardScreen(
      initialTab: _initialDashboardTab,
      onEditProfileRequested: () {
        setState(() => _isOnboarded = false);
      },
    );
  }
}

class InitialStudentSetupScreen extends StatefulWidget {
  final VoidCallback onCompletedOpenProfile;
  const InitialStudentSetupScreen({
    super.key,
    required this.onCompletedOpenProfile,
  });

  @override
  State<InitialStudentSetupScreen> createState() =>
      _InitialStudentSetupScreenState();
}

class _InitialStudentSetupScreenState extends State<InitialStudentSetupScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _courseCtrl = TextEditingController();
  String _selectedState = '';
  String _selectedCourse = 'B.Tech';
  String _selectedYear = '2nd Year';
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _prefillExisting();
  }

  Future<void> _prefillExisting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('user_name') ?? '';
      _emailCtrl.text = prefs.getString('user_email') ?? '';
      final c = prefs.getString('course') ?? 'B.Tech';
      if (c == 'B.Tech' || c == 'Degree') {
        _selectedCourse = c;
      } else {
        _selectedCourse = 'Other';
        _courseCtrl.text = c == 'Other' ? '' : c;
      }
      _selectedYear = prefs.getString('year') ?? '2nd Year';
      _selectedState = prefs.getString('state') ?? '';
    });
  }

  List<String> get _yearsForCourse {
    if (_selectedCourse == 'B.Tech') {
      return ['1st Year', '2nd Year', '3rd Year', '4th Year'];
    } else if (_selectedCourse == 'Degree') {
      return ['1st Year', '2nd Year', '3rd Year'];
    }
    return ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year'];
  }

  Future<void> _handleRestoreFromCloud() async {
    setState(() => _isRestoring = true);
    final account = await CloudBackupService.signInWithGoogle();
    if (account == null) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: ${CloudBackupService.lastError}'),
          duration: const Duration(seconds: 8),
        ),
      );
      return;
    }
    final email = account.email ?? '';
    _emailCtrl.text = email;
    final data = await CloudBackupService.restoreUserFromFirestore();
    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (data == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(CloudBackupService.lastError.isNotEmpty
              ? 'Could not read the backup: ${CloudBackupService.lastError}'
              : 'Signed in as $email. Fill in your details and tap Continue.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', data['userName'] ?? 'Student');
    await prefs.setString('user_email', email);
    await prefs.setString('course', data['course'] ?? 'B.Tech');
    await prefs.setString('year', data['year'] ?? '2nd Year');
    await prefs.setString('state', data['state'] ?? '');
    await prefs.setString('holiday_names', data['holidayNames'] ?? '{}');
    await prefs.setStringList(
        'hidden_hols', List<String>.from(data['hiddenHols'] ?? const []));
    await prefs.setString(
        'timetable_file', data['timetableFileName'] ?? 'Restored from Cloud');
    if (data['holidays'] != null) {
      await prefs.setStringList(
          'holidays', List<String>.from(data['holidays']));
    }
    if (data['subjects'] != null) {
      await prefs.setString('subjects', jsonEncode(data['subjects']));
    }
    if (data['historyLogs'] != null) {
      await prefs.setString('history_logs_v2', jsonEncode(data['historyLogs']));
    }
    await prefs.setBool('is_onboarded', true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Cloud Backup Restored Successfully!')),
    );
    widget.onCompletedOpenProfile();
  }

  Future<void> _saveAndGoToProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Name')),
      );
      return;
    }
    final email = _emailCtrl.text.trim().isEmpty
        ? '${name.toLowerCase().replaceAll(' ', '')}@gmail.com'
        : _emailCtrl.text.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString(
        'course',
        _selectedCourse == 'Other' && _courseCtrl.text.trim().isNotEmpty
            ? _courseCtrl.text.trim()
            : _selectedCourse);
    await prefs.setString('year', _selectedYear);
    await prefs.setString('state', _selectedState);

    if ((prefs.getString('subjects') ?? '').isEmpty) {
      final defaultSubs = <SubjectModel>[
      ];
      await prefs.setString(
        'subjects',
        jsonEncode(defaultSubs.map((s) => s.toJson()).toList()),
      );
    }

    await prefs.setBool('is_onboarded', true);
    widget.onCompletedOpenProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BoldPage(
        header: Column(
          children: [
            const AttendanceAppLogo(size: 72),
            const SizedBox(height: 12),
            const Text(
              'AttendTrack',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set up your profile to start tracking.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        children: [
          FadeSlideIn(
            index: 0,
            child: SoftCard(
              color: AppColors.tint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_circle_outlined, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text(
                        'Sign in with Google',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'New or returning, just sign in. If you have a saved backup it comes back; if not, fill in your details below.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        onPressed:
                            _isRestoring ? null : _handleRestoreFromCloud,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_isRestoring
                            ? 'Signing in...'
                            : 'Sign in with Google'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            child: _fieldLabel('Full name'),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 1,
            child: TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Madhav',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 2, child: _fieldLabel('Course')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 3,
            child: Row(
              children: ['B.Tech', 'Degree', 'Other'].map((c) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AppPill(
                      label: c,
                      selected: _selectedCourse == c,
                      onTap: () {
                        setState(() {
                          _selectedCourse = c;
                          _selectedYear = _yearsForCourse.first;
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          AnimatedSize(
            duration: kMed,
            curve: Curves.easeOutCubic,
            child: _selectedCourse == 'Other'
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: _courseCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Type your course, e.g. MBA, Diploma',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 4, child: _fieldLabel('Year')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 5,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _yearsForCourse.map((y) {
                final cur = _yearsForCourse.contains(_selectedYear)
                    ? _selectedYear
                    : _yearsForCourse.first;
                return SizedBox(
                  width: 104,
                  child: AppPill(
                    label: y,
                    selected: cur == y,
                    onTap: () => setState(() => _selectedYear = y),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 5, child: _fieldLabel('State (for holidays)')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 5,
            child: PressScale(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final v = await pickState(context, _selectedState);
                  if (v != null) setState(() => _selectedState = v);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_on_outlined),
                      suffixIcon: Icon(Icons.keyboard_arrow_down_rounded)),
                  child: Text(
                    _selectedState.isEmpty ? 'Select your state' : _selectedState,
                    style: TextStyle(
                        fontSize: 16,
                        color: _selectedState.isEmpty
                            ? AppColors.muted
                            : AppColors.ink),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(index: 6, child: _fieldLabel('Gmail (used for cloud backup)')),
          const SizedBox(height: 8),
          FadeSlideIn(
            index: 7,
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'yourname@gmail.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeSlideIn(
            index: 8,
            child: SizedBox(
              width: double.infinity,
              child: PressScale(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52)),
                  onPressed: _saveAndGoToProfile,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continue'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) => Text(
        t,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
      );
}

class MainDashboardScreen extends StatefulWidget {
  final int initialTab;
  final VoidCallback onEditProfileRequested;

  const MainDashboardScreen({
    super.key,
    required this.initialTab,
    required this.onEditProfileRequested,
  });

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _currentTab = 0;
  String _userName = 'Student';
  String _userEmail = 'student@gmail.com';
  String _course = 'B.Tech';
  String _year = '2nd Year';
  String _stateName = '';
  String _timetableFile = 'No PDF uploaded yet';
  String _lastBackup = 'Just now';
  bool _isReadingTimetable = false;

  static const List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];
  static const Map<String, String> _fullDayNames = {
    'Mon': 'Monday',
    'Tue': 'Tuesday',
    'Wed': 'Wednesday',
    'Thu': 'Thursday',
    'Fri': 'Friday',
    'Sat': 'Saturday',
  };
  String _selectedDayMode = 'All';
  int? _flashIdx;
  bool _flashPresent = true;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  List<SubjectModel> _subjects = [];
  Set<String> _holidays = {};
  Map<String, String> _holidayNames = {};
  String _holQuery = '';
  final _holSearchCtrl = TextEditingController();
  Set<String> _hiddenHols = {}; // 'yyyy-MM-dd|name' of state holidays removed
  List<AttendanceLogItem> _historyLogs = [];
  DateTime _selectedCalendarDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _selectedDayMode = _resolveDayShort(0);
    _loadAllData();
  }

  String _resolveDayShort(int offsetDays) {
    final dt = DateTime.now().add(Duration(days: offsetDays));
    switch (dt.weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
      case DateTime.sunday:
      default:
        return 'Sat';
    }
  }

  String get _activeWeekdayShort {
    if (_weekDays.contains(_selectedDayMode)) return _selectedDayMode;
    return 'All';
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final subRaw = prefs.getString('subjects') ?? '[]';
    final List<dynamic> decodedSubs = jsonDecode(subRaw);
    final logsRaw = prefs.getString('history_logs_v2') ?? '[]';
    final List<dynamic> decodedLogs = jsonDecode(logsRaw);

    setState(() {
      _userName = prefs.getString('user_name') ?? 'Student';
      _userEmail = prefs.getString('user_email') ?? 'student@gmail.com';
      _course = prefs.getString('course') ?? 'B.Tech';
      _year = prefs.getString('year') ?? '2nd Year';
      _stateName = prefs.getString('state') ?? '';
      _timetableFile =
          prefs.getString('timetable_file') ?? 'No PDF uploaded yet';
      _lastBackup = prefs.getString('last_cloud_backup') ?? 'Just now';
      _subjects = decodedSubs.map((e) => SubjectModel.fromJson(e)).toList();
      _holidays = (prefs.getStringList('holidays') ?? []).toSet();
      _holidayNames = Map<String, String>.from(
          jsonDecode(prefs.getString('holiday_names') ?? '{}') as Map);
      _hiddenHols = (prefs.getStringList('hidden_hols') ?? []).toSet();
      _historyLogs =
          decodedLogs.map((e) => AttendanceLogItem.fromJson(e)).toList();
    });
    // Old marks counted every slot as 1 class. Fix them from their time slot.
    var fixed = false;
    for (var k = 0; k < _historyLogs.length; k++) {
      final l = _historyLogs[k];
      final h = slotHours(l.slot);
      if (l.hours != 1 || h <= 1) continue;
      final si = _subjects.indexWhere((s) => s.name == l.subject);
      if (si != -1) {
        _subjects[si].totalHours += h - 1;
        if (l.present) _subjects[si].attendedHours += h - 1;
      }
      _historyLogs[k] = AttendanceLogItem(
          id: l.id,
          subject: l.subject,
          present: l.present,
          hours: h,
          dateKey: l.dateKey,
          timeStr: l.timeStr,
          slot: l.slot);
      fixed = true;
    }
    if (fixed) {
      setState(() {});
      _saveAllData();
    }
    _updateHomeWidgets();
  }

  Future<void> _updateHomeWidgets() async {
    try {
      await const MethodChannel('attendtrack/widget').invokeMethod('update', {
        'pct': _overallPct.round(),
        'status': _overallPct >= 75.0 ? 'Safe zone' : 'Below 75%',
      });
    } catch (_) {}
  }

  Future<void> _saveAllData({bool showSnack = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final nowStr = DateFormat('dd MMM, hh:mm a').format(DateTime.now());

    await prefs.setString(
        'subjects', jsonEncode(_subjects.map((s) => s.toJson()).toList()));
    await prefs.setStringList('holidays', _holidays.toList());
    await prefs.setString('history_logs_v2',
        jsonEncode(_historyLogs.map((l) => l.toJson()).toList()));
    await prefs.setString('timetable_file', _timetableFile);
    await prefs.setString('last_cloud_backup', nowStr);

    setState(() => _lastBackup = nowStr);
    _updateHomeWidgets();

    final cloudOk = await CloudBackupService.syncUserToFirestore(
      email: _userEmail,
      userName: _userName,
      course: _course,
      year: _year,
      timetableFileName: _timetableFile,
      subjects: _subjects,
      holidays: _holidays.toList(),
      historyLogs: _historyLogs,
    );

    final signedInNow = CloudBackupService.user != null;
    // Say nothing when it works; only speak up when a backup fails.
    if (!cloudOk && (signedInNow || showSnack) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(signedInNow
              ? 'Cloud backup failed: ${CloudBackupService.lastError}'
              : 'Saved on phone. Sign in with Google in Profile to back up to cloud.'),
        ),
      );
    }
  }

  int get _totalConducted => _subjects.fold(0, (sum, s) => sum + s.totalHours);
  int get _totalPresent => _subjects.fold(0, (sum, s) => sum + s.attendedHours);
  int get _totalAbsent => _totalConducted - _totalPresent;
  double get _overallPct =>
      _totalConducted == 0 ? 100.0 : (_totalPresent / _totalConducted) * 100.0;

  int get _overallSafeBunks {
    if (_totalConducted == 0 || _overallPct < 75.0) return 0;
    return (_totalPresent / 0.75 - _totalConducted).floor();
  }

  int get _overallNeededFor75 {
    if (_totalConducted == 0 || _overallPct >= 75.0) return 0;
    final n = (3 * _totalConducted) - (4 * _totalPresent);
    return n > 0 ? n : 1;
  }

  bool _logAttendance(int index, int hours, bool present) {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedCalendarDate);
    if (_holidays.contains(dateKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selected date is marked as a Holiday!')),
      );
      return false;
    }

    final timeStr = DateFormat('hh:mm a').format(DateTime.now());
    setState(() {
      _subjects[index].totalHours += hours;
      if (present) _subjects[index].attendedHours += hours;

      _historyLogs.insert(
        0,
        AttendanceLogItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          subject: _subjects[index].name,
          present: present,
          hours: hours,
          dateKey: dateKey,
          timeStr: timeStr,
          slot: _subjects[index].slotFor(
              DateFormat('E').format(_selectedCalendarDate)),
        ),
      );
    });
    _saveAllData();
    return true;
  }

  void _undoLogItem(AttendanceLogItem item) {
    setState(() {
      final subIdx = _subjects.indexWhere((s) => s.name == item.subject);
      if (subIdx != -1) {
        _subjects[subIdx].totalHours =
            (_subjects[subIdx].totalHours - item.hours).clamp(0, 9999);
        if (item.present) {
          _subjects[subIdx].attendedHours =
              (_subjects[subIdx].attendedHours - item.hours).clamp(0, 9999);
        }
      }
      _historyLogs.removeWhere((l) => l.id == item.id);
    });
    _saveAllData();
  }

  List<SubjectModel> _deduplicateSubjects(List<SubjectModel> rawList) {
    final Map<String, SubjectModel> uniqueMap = {};
    for (final item in rawList) {
      final cleanName = item.name.trim();
      if (cleanName.isEmpty) continue;
      final normKey =
          cleanName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (normKey.isEmpty) continue;

      if (uniqueMap.containsKey(normKey)) {
        final existing = uniqueMap[normKey]!;
        final mergedDays = {...existing.days, ...item.days}.toList();
        existing.days = mergedDays.isNotEmpty ? mergedDays : ['Mon', 'Wed', 'Fri'];
      } else {
        uniqueMap[normKey] = SubjectModel(
          name: cleanName,
          attendedHours: item.attendedHours,
          totalHours: item.totalHours,
          scheduleSlot: item.scheduleSlot,
          days: item.days.toSet().toList(),
          daySlots: item.daySlots,
        );
      }
    }
    return uniqueMap.values.toList();
  }

  Future<List<SubjectModel>> _aiReadTimetable(String path) async {
    if (CloudBackupService.user == null) {
      throw Exception('Sign in with Google first. The reader needs your account.');
    }
    final images = <String>[];
    try {
      if (path.toLowerCase().endsWith('.pdf')) {
        final doc = await PdfDocument.openFile(path);
        final n = doc.pagesCount > 3 ? 3 : doc.pagesCount;
        for (var i = 1; i <= n; i++) {
          final page = await doc.getPage(i);
          final w = 1280.0;
          final img = await page.render(
              width: w,
              height: w * page.height / page.width,
              format: PdfPageImageFormat.png,
              backgroundColor: '#FFFFFF');
          await page.close();
          if (img != null) images.add(base64Encode(img.bytes));
        }
        await doc.close();
      } else {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1280);
        final img = (await codec.getNextFrame()).image;
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        images.add(base64Encode(png!.buffer.asUint8List()));
      }
    } catch (_) {
      throw Exception("Couldn't open that file. Try another one.");
    }
    if (images.isEmpty) {
      throw Exception("Couldn't open that file. Try another one.");
    }
    final dynamic data;
    try {
      final res = await Supabase.instance.client.functions
          .invoke('read-timetable', body: {'images': images});
      data = res.data;
    } on FunctionException catch (e) {
      final d = e.details;
      final code = d is Map ? d['error'] : null;
      if (code == 'limit') {
        throw Exception("You've used today's 10 reads. Try again tomorrow, or add subjects by hand.");
      }
      if (code == 'busy') {
        throw Exception('The reader is busy right now. Try again in a few minutes.');
      }
      if (code == 'not_configured') {
        throw Exception('The reader is not switched on yet.');
      }
      throw Exception("The reader couldn't read that. Check your internet and try again.");
    } catch (_) {
      throw Exception('Check your internet and try again.');
    }
    final list = (data is Map ? data['subjects'] : null) as List? ?? [];
    final out = <SubjectModel>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString().trim();
      if (name.length < 2) continue;
      final code = (raw['code'] ?? '').toString().trim();
      final days = <String>[
        for (final d in (raw['days'] as List? ?? []))
          if (const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].contains(d.toString())) d.toString()
      ];
      final ds = <String, String>{};
      final slots = raw['slots'];
      if (slots is Map) {
        for (final e in slots.entries) {
          final mm = RegExp(
                  r'(\d{1,2}):(\d{2})\s*(AM|PM)\s*(?:-|–|to)\s*(\d{1,2}):(\d{2})\s*(AM|PM)')
              .firstMatch(e.value.toString().toUpperCase());
          if (mm == null) continue;
          String p2(String s) => s.padLeft(2, '0');
          final v =
              '${p2(mm[1]!)}:${mm[2]} ${mm[3]} - ${p2(mm[4]!)}:${mm[5]} ${mm[6]}';
          if (kTimeSlots.contains(v) && days.contains(e.key.toString())) {
            ds[e.key.toString()] = v;
          }
        }
      }
      out.add(SubjectModel(
        name: code.isEmpty ? name : '$name ($code)',
        scheduleSlot: ds.isNotEmpty ? ds.values.first : kTimeSlots.first,
        days: days,
        daySlots: ds,
      ));
    }
    return out;
  }

  Future<void> _pickAndReadTimetablePdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
      );
      if (res == null || res.files.isEmpty) return;

      final picked = res.files.first;
      setState(() {
        _isReadingTimetable = true;
        _timetableFile = picked.name;
      });

      List<SubjectModel> extracted = [];
      final path = picked.path;
      if (path != null) {
        try {
          extracted = await _aiReadTimetable(path);
        } catch (err) {
          setState(() => _isReadingTimetable = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(err.toString().replaceFirst('Exception: ', '')),
              duration: const Duration(seconds: 6)));
          return;
        }
      }

      if (extracted.isEmpty) {
        setState(() => _isReadingTimetable = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Couldn't read subjects from that file. Use a clear photo or screenshot, or add subjects by hand."),
            duration: Duration(seconds: 6)));
        return;
      }

      final deduplicated = _deduplicateSubjects(extracted);
      setState(() => _isReadingTimetable = false);
      if (!mounted) return;
      _showEditScannedTimetableDialog(deduplicated);
    } catch (e) {
      setState(() => _isReadingTimetable = false);
    }
  }

  void _showEditScannedTimetableDialog(List<SubjectModel> draftList) {
    final List<TextEditingController> ctrls =
        draftList.map((s) => TextEditingController(text: s.name)).toList();
    final List<String> slotList = draftList.map((s) {
      return kTimeSlots.contains(s.scheduleSlot)
          ? s.scheduleSlot
          : kTimeSlots.first;
    }).toList();
    final List<List<String>> daysList =
        draftList.map((s) => List<String>.from(s.days)).toList();
    final List<Map<String, String>> dsList =
        draftList.map((s) => Map<String, String>.from(s.daySlots)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SheetDialog(
          title: const Text(
            'Check your timetable',
            
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Fix any name and tap the days each class happens, then save.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(ctrls.length, (idx) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrls[idx],
                                  decoration: InputDecoration(
                                    labelText: 'Subject ${idx + 1} Name',
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setDialogState(() {
                                    ctrls.removeAt(idx);
                                    slotList.removeAt(idx);
                                    dsList.removeAt(idx);
                                    daysList.removeAt(idx);
                                  });
                                },
                                icon: Icon(Icons.delete_outline,
                                    color: AppColors.bad),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: kTimeSlots.map((slot) {
                              final sel = slotList[idx] == slot;
                              return GestureDetector(
                                onTap: () => setDialogState(
                                    () => slotList[idx] = slot),
                                child: AnimatedContainer(
                                  duration: kFast,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.tint,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(slot,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: sel
                                              ? Colors.white
                                              : AppColors.primary)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            children: _weekDays.map((d) {
                              final has = daysList[idx].contains(d);
                              return FilterChip(
                                label: Text(d,
                                    style: const TextStyle(fontSize: 10)),
                                selected: has,
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      daysList[idx].add(d);
                                    } else {
                                      daysList[idx].remove(d);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        ctrls.add(TextEditingController(text: 'New Subject'));
                        slotList.add(kTimeSlots.first);
                        dsList.add({});
                        daysList.add(['Mon', 'Wed', 'Fri']);
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Another Subject'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final List<SubjectModel> finalSubs = [];
                for (int i = 0; i < ctrls.length; i++) {
                  final text = ctrls[i].text.trim();
                  if (text.isNotEmpty) {
                    finalSubs.add(
                      SubjectModel(
                        name: text,
                        scheduleSlot: slotList[i],
                        daySlots: dsList[i],
                        days: daysList[i].isEmpty
                            ? ['Mon', 'Wed', 'Fri']
                            : daysList[i],
                      ),
                    );
                  }
                }
                if (finalSubs.isNotEmpty) {
                  setState(() => _subjects = _deduplicateSubjects(finalSubs));
                  _saveAllData(showSnack: true);
                }
                Navigator.pop(ctx);
                setState(() => _currentTab = 0);
              },
              child: const Text('Save Timetable'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSingleSubjectDialog(int subIndex) {
    final sub = _subjects[subIndex];
    final nameCtrl = TextEditingController(text: sub.name);
    final isCustom = !kTimeSlots.contains(sub.scheduleSlot);
    String selectedSlot = isCustom ? '__custom__' : sub.scheduleSlot;
    final customCtrl = TextEditingController(
        text: isCustom ? sub.scheduleSlot : '');
    final attCtrl = TextEditingController(text: sub.attendedHours.toString());
    final totCtrl = TextEditingController(text: sub.totalHours.toString());
    final List<String> selectedDays = List<String>.from(sub.days);
    final Map<String, String> daySlots = Map<String, String>.from(sub.daySlots);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SheetDialog(
          title: const Text('Edit subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                ),
                const SizedBox(height: 14),
                Text('Class time',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.ink)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...kTimeSlots.map((slot) {
                      final sel = selectedSlot == slot;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedSlot = slot),
                        child: AnimatedContainer(
                          duration: kFast,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : AppColors.tint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(slot,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : AppColors.primary)),
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: () => setDialogState(
                          () => selectedSlot = '__custom__'),
                      child: AnimatedContainer(
                        duration: kFast,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedSlot == '__custom__'
                              ? AppColors.primary
                              : AppColors.tint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Custom',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedSlot == '__custom__'
                                    ? Colors.white
                                    : AppColors.primary)),
                      ),
                    ),
                  ],
                ),
                if (selectedSlot == '__custom__') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customCtrl,
                    decoration: const InputDecoration(
                      labelText: 'e.g. 08:00 AM - 09:00 AM',
                      prefixIcon: Icon(Icons.access_time_rounded),
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: attCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Attended'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: totCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Total classes'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Class days',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.ink)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _weekDays.map((d) {
                    final has = selectedDays.contains(d);
                    return FilterChip(
                      label: Text(d),
                      selected: has,
                      onSelected: (val) {
                        setDialogState(() {
                          if (val) {
                            selectedDays.add(d);
                          } else {
                            selectedDays.remove(d);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                if (selectedDays.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Time on each day',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.ink)),
                  for (final d in _weekDays.where(selectedDays.contains))
                    Row(children: [
                      SizedBox(
                          width: 44,
                          child: Text(d,
                              style: TextStyle(color: AppColors.muted))),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: () {
                            final cur = daySlots[d] ??
                                (selectedSlot == '__custom__'
                                    ? customCtrl.text.trim()
                                    : selectedSlot);
                            return kTimeSlots.contains(cur) ? cur : null;
                          }(),
                          hint: const Text('Same as above'),
                          items: [
                            for (final t in kTimeSlots)
                              DropdownMenuItem(
                                  value: t,
                                  child: Text(t,
                                      style: const TextStyle(fontSize: 13)))
                          ],
                          onChanged: (v) =>
                              setDialogState(() => daySlots[d] = v!),
                        ),
                      ),
                    ]),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _subjects.removeAt(subIndex));
                _saveAllData();
                Navigator.pop(ctx);
              },
              child: Text('Delete', style: TextStyle(color: AppColors.bad)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final att = int.tryParse(attCtrl.text.trim()) ?? 0;
                final tot = int.tryParse(totCtrl.text.trim()) ?? 0;
                setState(() {
                  _subjects[subIndex].name = nameCtrl.text.trim().isEmpty
                      ? _subjects[subIndex].name
                      : nameCtrl.text.trim();
                  _subjects[subIndex].scheduleSlot =
                      selectedSlot == '__custom__'
                          ? (customCtrl.text.trim().isEmpty
                              ? kTimeSlots.first
                              : customCtrl.text.trim())
                          : selectedSlot;
                  _subjects[subIndex].daySlots = {
                    for (final e in daySlots.entries)
                      if (selectedDays.contains(e.key)) e.key: e.value
                  };
                  _subjects[subIndex].attendedHours = att < 0 ? 0 : att;
                  _subjects[subIndex].totalHours = tot < att ? att : tot;
                  _subjects[subIndex].days = selectedDays.isEmpty
                      ? ['Mon', 'Wed', 'Fri']
                      : selectedDays;
                });
                _saveAllData(showSnack: true);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  int _qrHash(String v) {
    var h = 0x811c9dc5;
    for (final u in v.codeUnits) {
      h ^= u;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  Future<void> _switchAccount([String? targetId]) async {
    final cur = CloudBackupService.user;
    if (cur != null) {
      await _saveAllData();
      await AccountStore.register(cur.id, cur.email ?? '');
      await AccountStore.snapshot(cur.id);
      await AccountStore.saveSession(cur.id);
    }
    CloudUser? u;
    if (targetId != null) {
      final saved = await AccountStore.sessionFor(targetId);
      if (saved != null) u = await CloudBackupService.recover(saved);
    }
    u ??= await CloudBackupService.signInWithGoogle();
    if (!mounted) return;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not switch: ${CloudBackupService.lastError}'),
            duration: const Duration(seconds: 8)),
      );
      setState(() {});
      return;
    }
    final email = u.email ?? '';
    await AccountStore.register(u.id, email);
    await AccountStore.saveSession(u.id);
    if (!await AccountStore.restore(u.id)) {
      final data = await CloudBackupService.restoreUserFromFirestore();
      await AccountStore.clear();
      if (data != null) {
        await AccountStore.applyCloud(data, email);
      } else {
        final p = await SharedPreferences.getInstance();
        await p.setString('user_name', email.split('@').first);
        await p.setString('user_email', email);
        await p.setBool('is_onboarded', true);
      }
    }
    await _loadAllData();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Now using $email')),
    );
  }

  Future<void> _deleteMyData() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SheetDialog(
        title: const Text('Delete my data?'),
        content: Text(
          'This erases all subjects, attendance and holidays on this phone'
          '${CloudBackupService.user != null ? ' and your cloud backup' : ''}. '
          'It cannot be undone.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bad),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final cur = CloudBackupService.user;
    var cloudNote = '';
    if (cur != null) {
      final done = await CloudBackupService.deleteBackup();
      cloudNote = done ? '' : ' Cloud backup could not be deleted.';
      await AccountStore.remove(cur.id);
    }
    await AccountStore.clear();
    await CloudBackupService.signOut();
    final others = await AccountStore.list();
    if (!mounted) return;
    if (others.isEmpty) {
      // Nobody else on this phone: back to the first-time setup screen.
      widget.onEditProfileRequested();
    } else {
      await _switchAccount(others.first['id'] as String?);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Your data was deleted.$cloudNote')),
    );
  }

  Future<void> _signOutAccount() async {
    final cur = CloudBackupService.user;
    if (cur != null) {
      await _saveAllData();
      await AccountStore.snapshot(cur.id);
    }
    await CloudBackupService.signOut();
    if (mounted) setState(() {});
  }

  Future<void> _signInForBackup() async {
    final u = await CloudBackupService.signInWithGoogle();
    if (!mounted) return;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Google sign-in failed: ${CloudBackupService.lastError}'),
            duration: const Duration(seconds: 8)),
      );
      return;
    }
    setState(() => _userEmail = u.email ?? _userEmail);
    await AccountStore.register(u.id, u.email ?? '');
    await AccountStore.saveSession(u.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', _userEmail);
    await _saveAllData(showSnack: true);
  }

  String _generateQrSharePayload() {
    final rows = _subjects
        .map((s) =>
            '${s.name.replaceAll(RegExp(r'[|;~]'), ' ')}~${s.days.join(',')}~${s.scheduleSlot.replaceAll(RegExp(r'[|;~]'), ' ')}')
        .join(';');
    final compact = 'AT2|$_course|$_year|College|$rows';
    return compact;
  }

  void _importQrPayload(String rawCode) {
    try {
      final trimmed = rawCode.trim();
      final decodedStr = trimmed.startsWith('AT2|')
          ? trimmed
          : utf8.decode(base64Decode(trimmed));
      if (decodedStr.startsWith('AT2|')) {
        final parts = decodedStr.split('|');
        if (parts.length >= 5) {
          final rows =
              parts[4].split(';').where((r) => r.trim().isNotEmpty).toList();
          final imported = rows.map((r) {
            final segs = r.split('~');
            return SubjectModel(
              name: segs.isNotEmpty ? segs[0] : 'Subject',
              days: segs.length > 1 && segs[1].isNotEmpty
                  ? segs[1].split(',')
                  : ['Mon', 'Wed', 'Fri'],
              scheduleSlot:
                  segs.length > 2 ? segs[2] : '09:30 AM - 10:30 AM',
            );
          }).toList();
          if (imported.isNotEmpty) {
            setState(() {
              _course = parts[1].isNotEmpty ? parts[1] : _course;
              _year = parts[2].isNotEmpty ? parts[2] : _year;
              _subjects = _deduplicateSubjects(imported);
            });
            _saveAllData(showSnack: true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Imported ${_subjects.length} unique subjects from QR!'),
              ),
            );
            return;
          }
        }
      }

      final decoded = jsonDecode(decodedStr);
      if (decoded['subjects'] != null) {
        final List<dynamic> list = decoded['subjects'];
        setState(() {
          _course = decoded['course'] ?? _course;
          _year = decoded['year'] ?? _year;
          _subjects = _deduplicateSubjects(
            list.map((item) {
              if (item is String) {
                return SubjectModel(name: item);
              }
              return SubjectModel(
                name: item['name'] ?? 'Subject',
                scheduleSlot: item['slot'] ?? '09:30 AM - 10:30 AM',
                days: item['days'] != null
                    ? List<String>.from(item['days'])
                    : ['Mon', 'Wed', 'Fri'],
              );
            }).toList(),
          );
        });
        _saveAllData(showSnack: true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR Code format.')),
      );
    }
  }

  void _openLiveCameraQrScanner() {
    final controller = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    bool handled = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.black,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Stack(
          children: [
            MobileScanner(
              controller: controller,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission denied.\nAllow Camera for this app in phone Settings, then try again.'
                            : 'Camera could not start (${error.errorCode.name}).\n${error.errorDetails?.message ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await controller.stop();
                          } catch (_) {}
                          try {
                            await controller.start();
                          } catch (_) {}
                        },
                        child: const Text('Try again'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () async {
                          final res = await FilePicker.platform
                              .pickFiles(type: FileType.image);
                          final path = res?.files.single.path;
                          if (path == null) return;
                          try {
                            final cap = await controller.analyzeImage(path);
                            final raw = cap?.barcodes.first.rawValue;
                            if (raw != null && !handled) {
                              handled = true;
                              if (ctx.mounted) Navigator.pop(ctx);
                              _importQrPayload(raw);
                            }
                          } catch (_) {}
                        },
                        child: const Text('Choose a QR photo instead'),
                      ),
                    ],
                  ),
                ),
              ),
              onDetect: (capture) {
                if (handled) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    handled = true;
                    Navigator.pop(ctx);
                    _importQrPayload(raw);
                    break;
                  }
                }
              },
            ),
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scan Classmate Timetable QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget Function()>[
      _buildHomeTab,
      _buildHistoryTab,
      _buildHolidaysTab,
      _buildQrAndStatsTab,
      _buildProfileAndTimetableTab,
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: kMed,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) =>
            reduceMotion(context) ? child : tabTransition(child, anim),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentTab),
          child: pages[_currentTab](),
        ),
      ),
      bottomNavigationBar: AppNavBar(
        index: _currentTab,
        onTap: (idx) => setState(() => _currentTab = idx),
      ),
    );
  }

  void _mark(int i, bool present) {
    final day = DateFormat('E').format(_selectedCalendarDate);
    final ok = _logAttendance(i, slotHours(_subjects[i].slotFor(day)), present);
    if (!ok) return;
    setState(() {
      _flashIdx = i;
      _flashPresent = present;
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _flashIdx = null);
    });
  }

  Widget _buildHomeTab() {
    final isSafe = _overallPct >= 75.0;
    final activeDay = _activeWeekdayShort;
    final visibleSubjects = _subjects.asMap().entries.where((entry) {
      if (activeDay == 'All') return true;
      return entry.value.days.contains(activeDay);
    }).toList();

    return BoldPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, $_userName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '$_course • $_year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _currentTab = 4),
                icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
                tooltip: 'Upload timetable',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              PctRing(
                pct: _overallPct,
                size: 112,
                textStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overall attendance',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: kFast,
                      child: Text(
                        isSafe ? 'Safe zone' : 'Below 75%',
                        key: ValueKey<bool>(isSafe),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSafe
                          ? 'You can skip $_overallSafeBunks more classes.'
                          : 'Attend the next $_overallNeededFor75 classes to reach 75%.',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: Row(
            children: [
              _tapStatCard('Present', _totalPresent, AppColors.good, true),
              const SizedBox(width: 8),
              _tapStatCard('Absent', _totalAbsent, AppColors.bad, false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          index: 1,
          child: Row(
            children: ['All', ..._weekDays].map((d) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AppPill(
                    label: d,
                    selected: activeDay == d,
                    onTap: () => setState(() => _selectedDayMode = d),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                activeDay == 'All'
                    ? 'All subjects (${_subjects.length})'
                    : "${_fullDayNames[activeDay]}'s classes (${visibleSubjects.length})",
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.ink),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _subjects.add(SubjectModel(name: 'New Subject'));
                });
                _showEditSingleSubjectDialog(_subjects.length - 1);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add subject'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (visibleSubjects.isEmpty)
          FadeSlideIn(
            child: SoftCard(
              child: Center(
                child: Text(
                  _subjects.isEmpty
                      ? 'No subjects yet. Tap Add subject, or import a timetable from the Profile tab.'
                      : 'No classes on this day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ),
          )
        else
          ...visibleSubjects.asMap().entries.map(
                (e) => _subjectCard(e.value.key, e.value.value, e.key),
              ),
      ],
    );
  }

  Widget _subjectCard(int i, SubjectModel sub, int order) {
    final ok = sub.percentage >= 75.0;
    final flash = _flashIdx == i;
    final pctColor = ok ? AppColors.good : AppColors.bad;
    final missed = (sub.totalHours - sub.attendedHours).clamp(0, 99999);
    final slot = _activeWeekdayShort == 'All'
        ? sub.scheduleSlot
        : sub.slotFor(_activeWeekdayShort);
    Widget stat(String v, String label, Color c) => Expanded(
          child: Column(
            children: [
              Text(v,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: c)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        );
    return FadeSlideIn(
      key: ValueKey('${sub.name}-$_selectedDayMode-$i'),
      index: order,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(sub.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _showEditSingleSubjectDialog(i),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16, color: Colors.white70),
                                  tooltip: 'Edit subject',
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('$slot  ·  ${sub.days.join(' ')}',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showSubjectAttendanceLog(sub),
                        child: PctRing(
                          pct: sub.percentage,
                          size: 56,
                          stroke: 6,
                          color: ok ? AppColors.accent : const Color(0xFFFFB4AB),
                          track: Colors.white24,
                          textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      stat('${sub.attendedHours}', 'Attended', AppColors.good),
                      stat('$missed', 'Missed', AppColors.bad),
                      stat('${sub.totalHours}', 'Total', AppColors.ink),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Center(
                    child: Text(
                      ok
                          ? 'Safe to skip ${sub.safeBunks} classes'
                          : 'Attend next ${sub.classesNeededFor75} classes for 75%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pctColor),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: PressScale(
                          child: FilledButton(
                            onPressed: () => _mark(i, true),
                            child: AnimatedSwitcher(
                              duration: kFast,
                              transitionBuilder: (c, a) =>
                                  ScaleTransition(scale: a, child: c),
                              child: (flash && _flashPresent)
                                  ? const Icon(Icons.check_rounded,
                                      key: ValueKey('p-check'))
                                  : const Text('Present',
                                      key: ValueKey('p-text')),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PressScale(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.tint,
                              foregroundColor: AppColors.primary,
                            ),
                            onPressed: () => _mark(i, false),
                            child: AnimatedSwitcher(
                              duration: kFast,
                              transitionBuilder: (c, a) =>
                                  ScaleTransition(scale: a, child: c),
                              child: (flash && !_flashPresent)
                                  ? const Icon(Icons.close_rounded,
                                      key: ValueKey('a-x'))
                                  : const Text('Absent',
                                      key: ValueKey('a-text')),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, int val, Color color) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 4),
            CountUp(
              value: val,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tapStatCard(String label, int val, Color color, bool isPresent) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _showAttendanceList(isPresent),
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 13, color: AppColors.muted)),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.muted),
              ]),
              const SizedBox(height: 4),
              CountUp(
                value: val,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubjectAttendanceLog(SubjectModel sub) {
    final logs = _historyLogs
        .where((l) => l.subject == sub.name)
        .toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

    final attended = logs.where((l) => l.present).length;
    final missed = logs.where((l) => !l.present).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SheetDialog(
        title: Text(sub.name),
        content: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.goodSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text('$attended',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.good)),
                      Text('Attended',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.badSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text('$missed',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.bad)),
                      Text('Missed',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Text('No attendance recorded yet.',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 15)),
                      )
                    : ListView.separated(
                        itemCount: logs.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppColors.line),
                        itemBuilder: (_, idx) {
                          final item = logs[idx];
                          DateTime? dt;
                          try {
                            dt = DateTime.parse(item.dateKey);
                          } catch (_) {}
                          final dateStr = dt != null
                              ? DateFormat('EEE, d MMM yyyy').format(dt)
                              : item.dateKey;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: item.present
                                  ? AppColors.goodSoft
                                  : AppColors.badSoft,
                              child: Icon(
                                item.present
                                    ? Icons.check_rounded
                                    : Icons.close_rounded,
                                size: 16,
                                color: item.present
                                    ? AppColors.good
                                    : AppColors.bad,
                              ),
                            ),
                            title: Text(
                              item.present ? 'Present' : 'Absent',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: item.present
                                      ? AppColors.good
                                      : AppColors.bad,
                                  fontSize: 14),
                            ),
                            subtitle: Text(
                              '${item.slot.isNotEmpty ? '${item.slot}\n' : ''}$dateStr${item.timeStr.isNotEmpty ? " • ${item.timeStr}" : ""}',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAttendanceList(bool isPresent) {
    final logs = _historyLogs
        .where((l) => l.present == isPresent)
        .toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SheetDialog(
        title: Text(
          isPresent ? 'Classes Attended' : 'Classes Missed',
        ),
        content: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: logs.isEmpty
              ? Center(
                  child: Text(
                    isPresent
                        ? 'No classes attended yet'
                        : 'No absences yet 🎉',
                    style: TextStyle(color: AppColors.muted, fontSize: 15),
                  ),
                )
              : ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1, color: AppColors.line),
                  itemBuilder: (_, i) {
                    final item = logs[i];
                    // parse dateKey yyyy-MM-dd
                    DateTime? dt;
                    try {
                      dt = DateTime.parse(item.dateKey);
                    } catch (_) {}
                    final dateStr = dt != null
                        ? DateFormat('EEE, d MMM yyyy').format(dt)
                        : item.dateKey;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isPresent
                            ? AppColors.goodSoft
                            : AppColors.badSoft,
                        child: Icon(
                          isPresent
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          size: 16,
                          color:
                              isPresent ? AppColors.good : AppColors.bad,
                        ),
                      ),
                      title: Text(item.subject,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                              fontSize: 14)),
                      subtitle: Text(
                        '${item.slot.isNotEmpty ? '${item.slot}\n' : ''}$dateStr${item.timeStr.isNotEmpty ? " • ${item.timeStr}" : ""}',
                        style: TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _dk(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  List<Holiday> _stateHols() => holidaysForState(_stateName)
      .where((h) => !_hiddenHols.contains('${_dk(h.date)}|${h.name}'))
      .toList();

  Future<void> _saveHolidayExtras() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('holidays', _holidays.toList());
    await prefs.setString('holiday_names', jsonEncode(_holidayNames));
    await prefs.setStringList('hidden_hols', _hiddenHols.toList());
    _saveAllData();
  }

  void _undoSnack(String text, VoidCallback undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              setState(undo);
              _saveHolidayExtras();
            }),
      ));
  }

  void _removeMyHoliday(String key) {
    final name = _holidayNames[key];
    setState(() {
      _holidays.remove(key);
      _holidayNames.remove(key);
    });
    _saveHolidayExtras();
    _undoSnack('Holiday removed', () {
      _holidays.add(key);
      if (name != null) _holidayNames[key] = name;
    });
  }

  void _hideStateHoliday(Holiday h) {
    final k = '${_dk(h.date)}|${h.name}';
    setState(() => _hiddenHols.add(k));
    _saveHolidayExtras();
    _undoSnack('Holiday hidden', () => _hiddenHols.remove(k));
  }

  Future<void> _addMyHoliday() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final ctrl = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SheetDialog(
        title: const Text('Holiday name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              hintText: 'Optional, e.g. College fest'),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null) return;
    setState(() {
      _holidays.add(_dk(d));
      if (name.isNotEmpty) _holidayNames[_dk(d)] = name;
    });
    _saveHolidayExtras();
  }

  Widget _buildHolidaysTab() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    bool match(DateTime d, String name) {
      final q = _holQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      final hay = '${name.toLowerCase()} '
          '${DateFormat('EEEE EEE d dd MMMM MMM yyyy M/d d/M').format(d).toLowerCase()}';
      return q.split(RegExp(r'\s+')).every(hay.contains);
    }

    final list = _stateHols()
        .where((h) => !h.date.isBefore(start) && match(h.date, h.name))
        .toList();
    final mine = _holidays
        .where((k) => match(DateTime.parse(k), _holidayNames[k] ?? 'Holiday'))
        .toList()
      ..sort();
    final children = <Widget>[
      TextField(
        controller: _holSearchCtrl,
        onChanged: (v) => setState(() => _holQuery = v),
        decoration: InputDecoration(
          hintText: 'Search name, month or date',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _holQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _holSearchCtrl.clear();
                    setState(() => _holQuery = '');
                  },
                ),
          isDense: true,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: Text('My holidays',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            onPressed: _addMyHoliday,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
      if (mine.isEmpty)
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Days you mark yourself show up here.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      for (final k in mine)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SoftCard(
            child: Row(
              children: [
                Icon(Icons.event_available_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_holidayNames[k] ?? 'Holiday',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Text(
                          DateFormat('EEEE, d MMM yyyy')
                              .format(DateTime.parse(k)),
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _removeMyHoliday(k),
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.bad),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
    ];
    if (_stateName.isEmpty) {
      children.add(FadeSlideIn(
        child: SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 48, color: AppColors.primary.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text('Pick your state to see holidays',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('State holidays will show here and in the calendar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final v = await pickState(context, _stateName);
                      if (v == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('state', v);
                      if (mounted) setState(() => _stateName = v);
                    },
                    child: const Text('Choose state'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    } else if (list.isEmpty) {
      children.add(FadeSlideIn(
        child: SoftCard(
          child: Center(
            child: Text('No more holidays in the list.',
                style: TextStyle(color: AppColors.muted, fontSize: 14)),
          ),
        ),
      ));
    } else {
      String month = '';
      var i = 0;
      for (final h in list) {
        final m = DateFormat('MMMM yyyy').format(h.date);
        if (m != month) {
          month = m;
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(m,
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ));
        }
        final days = h.date.difference(start).inDays;
        children.add(FadeSlideIn(
          index: i++ < 8 ? i : 8,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SoftCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.tint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(DateFormat('d').format(h.date),
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text(DateFormat('MMM').format(h.date),
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Image.asset('assets/holiday.png',
                              width: 20,
                              height: 20,
                              color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(h.name,
                                style: TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                            '${DateFormat('EEEE').format(h.date)} • ${days == 0 ? 'Today' : days == 1 ? 'Tomorrow' : 'in $days days'}',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hide',
                    onPressed: () => _hideStateHoliday(h),
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }
    return BoldPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Holidays',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_stateName.isEmpty ? 'No state selected' : _stateName,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
      children: children,
    );
  }

  Widget _buildHistoryTab() {
    final selectedKey = DateFormat('yyyy-MM-dd').format(_selectedCalendarDate);
    final dayLogs =
        _historyLogs.where((l) => l.dateKey == selectedKey).toList();
    final isHoliday = _holidays.contains(selectedKey);
    final stateHolList =
        _stateHols().where((h) => _dk(h.date) == selectedKey).toList();
    final stateHolNames = {for (final h in _stateHols()) _dk(h.date): h.name};
    final stateHolName =
        stateHolList.isEmpty ? null : stateHolList.map((h) => h.name).join(', ');
    final presentCount = dayLogs.where((l) => l.present).length;
    final absentCount = dayLogs.length - presentCount;

    return BoldPage(
      header: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Attendance history',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, d MMM yyyy').format(_selectedCalendarDate),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          PressScale(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySoft,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (isHoliday) {
                  _removeMyHoliday(selectedKey);
                } else {
                  setState(() => _holidays.add(selectedKey));
                  _saveAllData();
                }
              },
              icon: const Icon(Icons.wb_sunny_outlined, size: 18),
              label: Text(isHoliday ? 'Unmark holiday' : 'Mark holiday'),
            ),
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: SoftCard(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: HolidayCalendar(
                selected: _selectedCalendarDate,
                stateHolidays: stateHolNames.keys.toSet(),
                myHolidays: _holidays.toSet(),
                onSelect: (dt) => setState(() => _selectedCalendarDate = dt),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: kMed,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isHoliday
              ? Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: SoftCard(
                    color: AppColors.tint,
                    child: Row(
                      children: [
                        Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Holiday. Attendance is paused for this date.',
                            style:
                                TextStyle(fontSize: 13, color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (stateHolName != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SoftCard(
              color: AppColors.badSoft,
              child: Row(
                children: [
                  Icon(Icons.celebration_rounded, color: AppColors.bad),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(stateHolName,
                        style: TextStyle(
                            fontSize: 14, color: AppColors.ink)),
                  ),
                  TextButton(
                    onPressed: () => _hideStateHoliday(stateHolList.first),
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Logs on $selectedKey',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.ink),
              ),
            ),
            Text(
              'Present $presentCount • Absent $absentCount',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (dayLogs.isEmpty)
          FadeSlideIn(
            child: SoftCard(
              child: Center(
                child: Text(
                  'No classes logged for this date yet.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ),
          )
        else
          ...dayLogs.asMap().entries.map((e) {
            final item = e.value;
            return FadeSlideIn(
              key: ValueKey(item.id),
              index: e.key,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: item.present
                            ? AppColors.goodSoft
                            : AppColors.badSoft,
                        child: Icon(
                          item.present ? Icons.check : Icons.close,
                          color: item.present ? AppColors.good : AppColors.bad,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.subject,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                            if (item.slot.isNotEmpty)
                              Text(item.slot,
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.primary)),
                            Text(
                              '${item.present ? "Present" : "Absent"} (${item.hours} ${item.hours == 1 ? "class" : "classes"}) • ${item.timeStr}',
                              style: TextStyle(
                                  fontSize: 13, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _undoLogItem(item),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.bad),
                        child: const Text('Undo'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _qrBlock(String qrPayload) {
    final h = _qrHash(qrPayload);
    const style = kAppQrStyle;
    final code6 = (h % 1000000).toString().padLeft(6, '0');
    final qr = QrImage(QrCode.fromData(
      data: qrPayload,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    ));
    return Column(
      key: ValueKey(code6),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(painter: StyledQrPainter(qr, style)),
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 4),
        Text(
          code6,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: 4,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: _subjects
              .map((sub) => Chip(
                    label: Text(sub.name, style: const TextStyle(fontSize: 13)),
                    visualDensity: VisualDensity.compact,
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQrAndStatsTab() {
    final qrPayload = _generateQrSharePayload();
    return BoldPage(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share timetable',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            "Scan a classmate's QR to copy their subjects and days.",
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: PressScale(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 52),
                ),
                onPressed: _openLiveCameraQrScanner,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Scan classmate QR'),
              ),
            ),
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: SoftCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Your timetable QR',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: kMed,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _qrBlock(qrPayload),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrPayload));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied class code!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy timetable code'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAndTimetableTab() {
    final signedIn = CloudBackupService.user != null;
    return BoldPage(
      header: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primarySoft,
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'S',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  _userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: widget.onEditProfileRequested,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit setup'),
          ),
        ],
      ),
      children: [
        FadeSlideIn(
          child: SoftCard(
            child: Column(
              children: [
                _profileRow('Course', _course),
                const SizedBox(height: 8),
                _profileRow('Year', _year),
                const SizedBox(height: 8),
                _profileRow('State', _stateName.isEmpty ? 'Not set' : _stateName),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 1,
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Timetable',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'File: $_timetableFile (${_subjects.length} subjects)',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                AnimatedSize(
                  duration: kMed,
                  child: _isReadingTimetable
                      ? const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    child: FilledButton.icon(
                      onPressed:
                          _isReadingTimetable ? null : _pickAndReadTimetablePdf,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(_isReadingTimetable
                          ? 'Reading file...'
                          : 'Upload PDF or image'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 2,
          child: SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      signedIn
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: signedIn ? AppColors.good : AppColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Text('Cloud backup',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  !signedIn
                      ? 'Not signed in. Cloud backup is off.'
                      : 'Last synced: $_lastBackup • ${CloudBackupService.user?.email ?? _userEmail}',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                if (!signedIn) ...[
                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      child: FilledButton.icon(
                        onPressed: _signInForBackup,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in with Google'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: PressScale(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveAllData(showSnack: true),
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Back up now'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          index: 3,
          child: SoftCard(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: AccountStore.list(),
              builder: (context, snap) {
                final accounts = snap.data ?? const <Map<String, dynamic>>[];
                final curId = CloudBackupService.user?.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.people_alt_outlined,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Accounts',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                    ]),
                    const SizedBox(height: 8),
                    if (accounts.isEmpty)
                      Text('Sign in to add an account.',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    for (final a in accounts)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.tint,
                          child: Text(
                              ((a['email'] as String?)?.isNotEmpty ?? false)
                                  ? (a['email'] as String)[0].toUpperCase()
                                  : '?',
                              style: TextStyle(color: AppColors.primary)),
                        ),
                        title: Text(a['email'] as String? ?? '',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.ink)),
                        trailing: a['id'] == curId
                            ? Icon(Icons.check_circle,
                                color: AppColors.good, size: 20)
                            : TextButton(
                                onPressed: () =>
                                    _switchAccount(a['id'] as String?),
                                child: const Text('Switch')),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: PressScale(
                        child: OutlinedButton.icon(
                          onPressed: _switchAccount,
                          icon: const Icon(Icons.swap_horiz_rounded),
                          label: const Text('Add or switch account'),
                        ),
                      ),
                    ),
                    if (signedIn)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _signOutAccount,
                          child: const Text('Sign out'),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _deleteMyData,
                        child: Text('Delete my data',
                            style: TextStyle(color: AppColors.bad)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileRow(String label, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
        Flexible(
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}


class QrStyleSpec {
  final String name;
  final Color bg;
  final List<Color> fg;
  final bool grad;
  final String shape;
  final List<double> eye;
  final Color? eyeColor;
  final bool leafEyes;
  const QrStyleSpec(this.name, this.bg, this.fg, this.shape, this.eye,
      {this.grad = false, this.eyeColor, this.leafEyes = false});
}

const QrStyleSpec kAppQrStyle = QrStyleSpec(
    'App', Color(0xFFFFFDD0), [Color(0xFF1B3320)], 'mosaic', [1.2, 0.6, 0.5]);

const List<QrStyleSpec> kQrStyles = [
  QrStyleSpec('Leaf', Color(0xFFF1F8EC), [Color(0xFF1F6B2E)], 'leaf',
      [2.6, 1.6, 1.1],
      leafEyes: true),
  QrStyleSpec('Diamond', Color(0xFFF4F0FF),
      [Color(0xFF311B92), Color(0xFF7C4DFF)], 'diamond', [1.2, 0.6, 0.4],
      grad: true),
  QrStyleSpec('Tall bars', Color(0xFFFFF7EC),
      [Color(0xFFBF360C), Color(0xFFF57C00)], 'vpill', [2, 1.2, 0.9],
      grad: true),
  QrStyleSpec(
      'Mosaic',
      Color(0xFFFFFFFF),
      [Color(0xFF0D47A1), Color(0xFFAD1457), Color(0xFF00695C), Color(0xFFE65100)],
      'mosaic',
      [0.8, 0.4, 0.3],
      eyeColor: Color(0xFF0D1B4A)),
  QrStyleSpec('Liquid', Color(0xFFEEF3FF),
      [Color(0xFF0D1B4A), Color(0xFF1976D2)], 'liquid', [3, 2, 1.4],
      grad: true),
];

class StyledQrPainter extends CustomPainter {
  final QrImage qr;
  final QrStyleSpec st;
  StyledQrPainter(this.qr, this.st);

  bool _isEye(int r, int c, int n) =>
      (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);

  @override
  void paint(Canvas canvas, Size size) {
    final n = qr.moduleCount;
    const q = 3;
    final s = size.width / (n + 2 * q);
    canvas.drawRect(Offset.zero & size, Paint()..color = st.bg);

    final paint = Paint()..isAntiAlias = true;
    if (st.grad) {
      paint.shader = ui.Gradient.linear(
          Offset.zero, Offset(size.width, size.height), [st.fg[0], st.fg[1]]);
    } else {
      paint.color = st.fg[0];
    }

    bool dark(int r, int c) =>
        r >= 0 && c >= 0 && r < n && c < n && qr.isDark(r, c) && !_isEye(r, c, n);

    void rr(double x, double y, double w, double h, double tl, double tr,
        double br, double bl, Paint p) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, w, h),
          topLeft: Radius.circular(tl),
          topRight: Radius.circular(tr),
          bottomRight: Radius.circular(br),
          bottomLeft: Radius.circular(bl),
        ),
        p,
      );
    }

    if (st.shape == 'vpill') {
      final pad = s * 0.107;
      final w = s - 2 * pad;
      for (var k = 0; k < n; k++) {
        var run = -1;
        for (var r = 0; r <= n; r++) {
          final on = dark(r, k);
          if (on && run < 0) run = r;
          if (!on && run >= 0) {
            rr((k + q) * s + pad, (run + q) * s + pad, w, (r - run) * s - 2 * pad,
                w / 2, w / 2, w / 2, w / 2, paint);
            run = -1;
          }
        }
      }
    } else {
      for (var r = 0; r < n; r++) {
        for (var k = 0; k < n; k++) {
          if (!dark(r, k)) continue;
          final x = (k + q) * s;
          final y = (r + q) * s;
          final inset = s * 0.035;
          if (st.shape == 'leaf') {
            rr(x + inset, y + inset, s - 2 * inset, s - 2 * inset, s * .5, 0,
                s * .5, 0, paint);
          } else if (st.shape == 'diamond') {
            final h = s * 0.6;
            final cx = x + s / 2;
            final cy = y + s / 2;
            final path = Path()
              ..moveTo(cx, cy - h)
              ..lineTo(cx + h, cy)
              ..lineTo(cx, cy + h)
              ..lineTo(cx - h, cy)
              ..close();
            canvas.drawPath(path, paint);
          } else if (st.shape == 'mosaic') {
            final mp = Paint()
              ..isAntiAlias = true
              ..color = st.fg[(r * 5 + k * 3 + (r * k) % 2) % st.fg.length];
            rr(x + inset, y + inset, s - 2 * inset, s - 2 * inset, s * .2,
                s * .2, s * .2, s * .2, mp);
          } else {
            final rad = s * .5;
            final tl = (!dark(r - 1, k) && !dark(r, k - 1)) ? rad : 0.0;
            final tr = (!dark(r - 1, k) && !dark(r, k + 1)) ? rad : 0.0;
            final br = (!dark(r + 1, k) && !dark(r, k + 1)) ? rad : 0.0;
            final bl = (!dark(r + 1, k) && !dark(r, k - 1)) ? rad : 0.0;
            rr(x - .02 * s, y - .02 * s, s * 1.04, s * 1.04, tl, tr, br, bl, paint);
          }
        }
      }
    }

    final eyePaint = Paint()..isAntiAlias = true;
    if (st.eyeColor != null) {
      eyePaint.color = st.eyeColor!;
    } else {
      eyePaint.shader = paint.shader;
      eyePaint.color = st.fg[0];
    }
    final bgPaint = Paint()
      ..isAntiAlias = true
      ..color = st.bg;
    for (final p in [
      [0, 0],
      [0, n - 7],
      [n - 7, 0]
    ]) {
      final x = (p[1] + q) * s;
      final y = (p[0] + q) * s;
      void box(double ox, double oy, double sz, double v, Paint pt) {
        final r = v * s;
        if (st.leafEyes) {
          rr(x + ox * s, y + oy * s, sz * s, sz * s, r, 0, r, 0, pt);
        } else {
          rr(x + ox * s, y + oy * s, sz * s, sz * s, r, r, r, r, pt);
        }
      }

      box(0, 0, 7, st.eye[0], eyePaint);
      box(1, 1, 5, st.eye[1], bgPaint);
      box(2, 2, 3, st.eye[2], eyePaint);
    }
  }

  @override
  bool shouldRepaint(covariant StyledQrPainter old) =>
      old.qr != qr || old.st != st;
}
