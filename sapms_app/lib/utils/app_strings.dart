// ============================================================
// SAPMS - App Localizations (English + Kinyarwanda)
// ============================================================
// Fulfils the proposal's "Kinyarwanda UI option" contextual enabler
// (§2.6 Table 2.2, §3.7 Figure 3.1). Rather than the full ARB/gen-l10n
// toolchain, this uses a lightweight in-memory string map keyed by a
// stable ID — quick to extend, no codegen, and easy for a Kinyarwanda
// speaker to review/correct in one file before the defense.
//
// Kinyarwanda translations should be reviewed by a native speaker
// (the proposal §3.5.4 describes a translate/back-translate process);
// they're written here to be clear and natural, but a final human
// pass is recommended before submission.
// ============================================================

class AppStrings {
  final String languageCode; // 'en' or 'rw'
  AppStrings(this.languageCode);

  String t(String key) => _values[languageCode]?[key] ?? _values['en']?[key] ?? key;

  static const Map<String, Map<String, String>> _values = {
    'en': {
      // ── App-wide ──
      'app_name': 'SAPMS',
      'app_full_name': 'Student Attendance & Performance Monitoring System',
      'university': 'University of Kigali',
      'language': 'Language',
      'english': 'English',
      'kinyarwanda': 'Kinyarwanda',

      // ── Login ──
      'sign_in': 'Sign In',
      'nyamasheke_schools': 'Nyamasheke District Schools',
      'email_address': 'Email Address',
      'password': 'Password',
      'demo_accounts': 'Demo Accounts (password: Sapms@2025)',
      'admin': 'Admin',
      'teacher': 'Teacher',
      'parent': 'Parent',
      'choose_language': 'Choose language',

      // ── Common actions ──
      'save': 'Save',
      'cancel': 'Cancel',
      'close': 'Close',
      'start': 'Start',
      'sync_now': 'Sync Now',
      'logout': 'Logout',
      'retry': 'Retry',
      'loading': 'Loading...',

      // ── Dashboard / navigation ──
      'dashboard': 'Dashboard',
      'attendance': 'Attendance',
      'performance': 'Performance',
      'students': 'Students',
      'at_risk_students': 'At-Risk Students',
      'notifications': 'Notifications',
      'reports': 'Reports',
      'home': 'Home',
      'my_children': 'My Children',

      // ── Attendance screen ──
      'take_attendance': 'Take Attendance',
      'session_active': 'Session Active',
      'no_active_session': 'No Active Session',
      'close_session': 'Close Session',
      'qr_scanner': 'QR Scanner',
      'tap_to_scan': 'Tap to start scanning',
      'scanned_students': 'Scanned Students',
      'session_summary': 'Session Summary',
      'present': 'Present',
      'absent': 'Absent',
      'late': 'Late',
      'excused': 'Excused',
      'scanned_count': 'Scanned',
      'students_expected': 'students expected',
      'offline_saving': 'Offline — scans are being saved on this device',
      'scans_waiting': 'scan(s) waiting to sync',
      'unsynced_scans': 'Unsynced scans',
      'close_anyway': 'Close Anyway',
      'marked_present': 'marked present',
      'no_connection_saved': 'No connection — scan saved offline, will sync automatically',

      // ── Performance / marks ──
      'marks': 'Marks',
      'enter_marks': 'Enter Marks',
      'subject': 'Subject',
      'score': 'Score',
      'grade': 'Grade',
      'attendance_rate': 'Attendance Rate',
      'gpa': 'GPA',
      'risk_level': 'Risk Level',
      'high_risk': 'High Risk',
      'moderate_risk': 'Moderate Risk',
      'low_risk': 'Low Risk',

      // ── Parent view ──
      'child_attendance': 'Child Attendance',
      'academic_performance': 'Academic Performance',
      'recent_alerts': 'Recent Alerts',

      // ── Teacher home ──
      'sapms_teacher': 'SAPMS Teacher',
      'hello': 'Hello',
      'what_to_do_today': 'What would you like to do today?',
      'quick_actions': 'Quick Actions',
      'take_attendance_sub': 'Open a session and scan student QR codes',
      'enter_marks_sub': 'Record student assessment scores',
      'offline_mode': 'Offline Mode',
      'offline_mode_desc': 'Attendance taken without internet will sync automatically when connection is restored.',

      // ── Marks screens ──
      'assessments_marks': 'Assessments & Marks',
      'no_assessments': 'No assessments found',
      'max': 'Max',
      'date': 'Date',
      'avg': 'Avg',
      'highest': 'Highest',
      'lowest': 'Lowest',

      // ── Parent home ──
      'sapms_parent': 'SAPMS Parent',
      'child_progress_portal': 'Child Progress Portal',
      'no_children_linked': 'No children linked to your account',
      'select_child': 'Select Child',
      'attendance_this_term': 'Attendance This Term',
      'rate': 'Rate',
      'attendance_below_warning': 'Attendance is below 85%. Please contact the school.',
      'no_marks_yet': 'No marks yet',
      'risk': 'RISK',

      // ── Admin dashboard ──
      'welcome': 'Welcome',
      'academic_year_term': 'Term 2 • 2024-2025 Academic Year',
      'school_overview': 'School Overview',
      'total_students': 'Total Students',
      'avg_attendance': 'Avg Attendance',
      'this_term': 'This term',
      'average_gpa': 'Average GPA',
      'all_subjects': 'All subjects',
      'absences_7d': 'Absences (7d)',
      'last_7_days': 'Last 7 days',
      'risk_distribution': 'Student Risk Distribution',
      'moderate': 'Moderate',
      'view_all': 'View All',
      'high_risk_intervention': 'student(s) at HIGH risk — immediate intervention needed',
      'no_at_risk_detected': 'No at-risk students detected',
      'students_need_attention': 'students need attention',
      'high_risk_moderate_risk': 'high risk • {mod} moderate risk',
      'classes': 'Classes',
      'no_classes_found': 'No classes found',
      'students_count': 'students',
      'avg_attendance_label': 'Avg attendance',
      'at_risk_count': 'at risk',

      // ── At-risk screen ──
      'all': 'All',
      'no_students_match': 'No students match this filter',
      'risk_score': 'Risk Score',
      'parent_label': 'Parent',

      // ── Students screen ──
      'search_students': 'Search students...',
      'no_students_found': 'No students found',

      // ── Student detail ──
      'student': 'Student',
      'overview': 'Overview',
      'qr_code': 'QR Code',
      'parent_guardian': 'Parent / Guardian',
      'sessions': 'Sessions',
      'recent_records': 'Recent Records',
      'qr_not_available': 'QR code not available',
      'student_qr_code': 'Student QR Code',
      'print_qr_note': 'Print this QR code on the student ID card.',
    },

    'rw': {
      // ── App-wide ──
      'app_name': 'SAPMS',
      'app_full_name': 'Sisitemu yo Gukurikirana Ukwitabira n\'Imikorere y\'Abanyeshuri',
      'university': 'Kaminuza ya Kigali',
      'language': 'Ururimi',
      'english': 'Icyongereza',
      'kinyarwanda': 'Ikinyarwanda',

      // ── Login ──
      'sign_in': 'Injira',
      'nyamasheke_schools': 'Amashuri yo mu Karere ka Nyamasheke',
      'email_address': 'Aderesi ya Imeyili',
      'password': 'Ijambobanga',
      'demo_accounts': 'Konti z\'igerageza (ijambobanga: Sapms@2025)',
      'admin': 'Umuyobozi',
      'teacher': 'Umwarimu',
      'parent': 'Umubyeyi',
      'choose_language': 'Hitamo ururimi',

      // ── Common actions ──
      'save': 'Bika',
      'cancel': 'Hagarika',
      'close': 'Funga',
      'start': 'Tangira',
      'sync_now': 'Ohereza nonaha',
      'logout': 'Sohoka',
      'retry': 'Ongera ugerageze',
      'loading': 'Biratunganywa...',

      // ── Dashboard / navigation ──
      'dashboard': 'Imbonerahamwe',
      'attendance': 'Ukwitabira',
      'performance': 'Imikorere',
      'students': 'Abanyeshuri',
      'at_risk_students': 'Abanyeshuri bafite ibibazo',
      'notifications': 'Ubutumwa',
      'reports': 'Raporo',
      'home': 'Ahabanza',
      'my_children': 'Abana banjye',

      // ── Attendance screen ──
      'take_attendance': 'Andika Ukwitabira',
      'session_active': 'Igihe cyo kwandika kiragikora',
      'no_active_session': 'Nta gihe cyo kwandika gihari',
      'close_session': 'Funga igikorwa',
      'qr_scanner': 'Gusoma QR',
      'tap_to_scan': 'Kanda utangire gusoma',
      'scanned_students': 'Abanyeshuri basomwe',
      'session_summary': 'Incamake y\'igikorwa',
      'present': 'Yaje',
      'absent': 'Yasibye',
      'late': 'Yatinze',
      'excused': 'Yaronse uruhushya',
      'scanned_count': 'Basomwe',
      'students_expected': 'abanyeshuri bategerejwe',
      'offline_saving': 'Nta murongo — ukwitabira kubikwa kuri iyi telefone',
      'scans_waiting': 'ukwitabira gutegereje koherezwa',
      'unsynced_scans': 'Ukwitabira kutaroherejwe',
      'close_anyway': 'Funga uko biri',
      'marked_present': 'yanditswe nk\'uwaje',
      'no_connection_saved': 'Nta murongo — ukwitabira kubitswe, bizoherezwa byikoreye',

      // ── Performance / marks ──
      'marks': 'Amanota',
      'enter_marks': 'Andika Amanota',
      'subject': 'Isomo',
      'score': 'Amanota',
      'grade': 'Urwego',
      'attendance_rate': 'Igipimo cyo kwitabira',
      'gpa': 'Impuzandengo y\'amanota',
      'risk_level': 'Urwego rw\'ibyago',
      'high_risk': 'Ibyago bikomeye',
      'moderate_risk': 'Ibyago biringaniye',
      'low_risk': 'Ibyago bike',

      // ── Parent view ──
      'child_attendance': 'Ukwitabira kw\'umwana',
      'academic_performance': 'Imikorere mu masomo',
      'recent_alerts': 'Imenyesha rya vuba',

      // ── Teacher home ──
      'sapms_teacher': 'SAPMS Umwarimu',
      'hello': 'Muraho',
      'what_to_do_today': 'Ni iki wifuza gukora uyu munsi?',
      'quick_actions': 'Ibikorwa byihuse',
      'take_attendance_sub': 'Fungura igikorwa maze usome kode QR z\'abanyeshuri',
      'enter_marks_sub': 'Andika amanota y\'ibizamini by\'abanyeshuri',
      'offline_mode': 'Uburyo bwo gukora nta murongo',
      'offline_mode_desc': 'Ukwitabira kwanditswe nta murongo kuzoherezwa byikoreye igihe umurongo ugarutse.',

      // ── Marks screens ──
      'assessments_marks': 'Ibizamini n\'Amanota',
      'no_assessments': 'Nta bizamini biboneka',
      'max': 'Ntarengwa',
      'date': 'Itariki',
      'avg': 'Impuzandengo',
      'highest': 'Hejuru cyane',
      'lowest': 'Hasi cyane',

      // ── Parent home ──
      'sapms_parent': 'SAPMS Umubyeyi',
      'child_progress_portal': 'Urubuga rw\'iterambere ry\'umwana',
      'no_children_linked': 'Nta bana bahujwe na konti yawe',
      'select_child': 'Hitamo umwana',
      'attendance_this_term': 'Ukwitabira muri iki gihembwe',
      'rate': 'Igipimo',
      'attendance_below_warning': 'Ukwitabira kuri munsi ya 85%. Nyamuneka vugana n\'ishuri.',
      'no_marks_yet': 'Nta manota arahaboneka',
      'risk': 'IBYAGO',

      // ── Admin dashboard ──
      'welcome': 'Murakaza neza',
      'academic_year_term': 'Igihembwe cya 2 • Umwaka w\'amashuri 2024-2025',
      'school_overview': 'Incamake y\'ishuri',
      'total_students': 'Abanyeshuri bose',
      'avg_attendance': 'Impuzandengo yo kwitabira',
      'this_term': 'Iki gihembwe',
      'average_gpa': 'Impuzandengo y\'amanota',
      'all_subjects': 'Amasomo yose',
      'absences_7d': 'Ukudataha (iminsi 7)',
      'last_7_days': 'Iminsi 7 ishize',
      'risk_distribution': 'Igabanya ry\'ibyago by\'abanyeshuri',
      'moderate': 'Biringaniye',
      'view_all': 'Reba byose',
      'high_risk_intervention': 'umunyeshuri/abanyeshuri bafite ibyago bikomeye — hakenewe kubafasha vuba',
      'no_at_risk_detected': 'Nta banyeshuri bafite ibyago babonetse',
      'students_need_attention': 'abanyeshuri bakeneye kwitabwaho',
      'high_risk_moderate_risk': 'ibyago bikomeye • {mod} ibyago biringaniye',
      'classes': 'Amashuri',
      'no_classes_found': 'Nta mashuri aboneka',
      'students_count': 'abanyeshuri',
      'avg_attendance_label': 'Impuzandengo yo kwitabira',
      'at_risk_count': 'bafite ibyago',

      // ── At-risk screen ──
      'all': 'Byose',
      'no_students_match': 'Nta munyeshuri uhuye n\'iyi mishyikirano',
      'risk_score': 'Amanota y\'ibyago',
      'parent_label': 'Umubyeyi',

      // ── Students screen ──
      'search_students': 'Shakisha abanyeshuri...',
      'no_students_found': 'Nta banyeshuri baboneka',

      // ── Student detail ──
      'student': 'Umunyeshuri',
      'overview': 'Incamake',
      'qr_code': 'Kode QR',
      'parent_guardian': 'Umubyeyi / Umurezi',
      'sessions': 'Ibikorwa',
      'recent_records': 'Amakuru ya vuba',
      'qr_not_available': 'Kode QR ntiboneka',
      'student_qr_code': 'Kode QR y\'umunyeshuri',
      'print_qr_note': 'Sohora iyi kode QR ku ikarita y\'umunyeshuri.',
    },
  };
}
