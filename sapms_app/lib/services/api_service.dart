import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  static const String _tokenKey = 'sapms_token';
  static const String _userKey  = 'sapms_user';

  // -- Configurable base URL -------------------------------------
  // Stored in SharedPreferences so the teacher/admin can change the
  // server IP from the app without needing a rebuild - useful when
  // the tethering IP changes between sessions.
  static String _runtimeBaseUrl = AppConstants.baseUrl;
  static String get effectiveBaseUrl => _runtimeBaseUrl;

  static Future<void> loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('sapms_base_url');
    if (saved != null && saved.isNotEmpty) _runtimeBaseUrl = saved;
  }

  static Future<void> saveUrl(String url) async {
    var u = url.trim();
    if (!u.endsWith('/api')) u = '$u/api';
    _runtimeBaseUrl = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sapms_base_url', u);
  }

  static Future<void> resetUrl() async {
    _runtimeBaseUrl = AppConstants.baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sapms_base_url');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_userKey);
    if (str == null) return null;
    return jsonDecode(str);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // -- HTTP Helpers -----------------------------------------
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(body['message'] ?? 'Request failed (${res.statusCode})');
  }

  // -- Auth -------------------------------------------------
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/auth/login'),
      headers: await _headers(auth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _parse(res);
    await saveToken(data['token']);
    await saveUser(data['user']);
    return data;
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/auth/me'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // -- Analytics --------------------------------------------
  static Future<Map<String, dynamic>> getDashboard({String? termId}) async {
    var url = '${ApiService.effectiveBaseUrl}/analytics/dashboard';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  // -- Blockchain ----------------------------------------------
  // Fetch the full ledger (newest block first).
  static Future<Map<String, dynamic>> getBlockchain() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/blockchain/chain'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // Verify the whole chain's integrity -> { valid: bool, brokenAt?, reason? }.
  static Future<Map<String, dynamic>> verifyBlockchain() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/blockchain/verify'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // -- Registration & approval ---------------------------------
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? schoolId,
    String? studentCode,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/auth/register'),
      headers: await _headers(auth: false),
      body: jsonEncode({
        'name': name, 'email': email, 'password': password, 'role': role,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (schoolId != null) 'school_id': schoolId,
        if (studentCode != null && studentCode.isNotEmpty) 'student_code': studentCode,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getPendingUsers() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/auth/pending'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> reviewUser(String id, String action) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/auth/review/$id'),
      headers: await _headers(),
      body: jsonEncode({'action': action}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getSchools() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/schools'),
      headers: await _headers(auth: false),
    );
    return _parse(res);
  }

  // -- Performance forecasting (F2) ----------------------------
  static Future<Map<String, dynamic>> getStudentForecasts(String studentId, {String? termId}) async {
    var url = '${ApiService.effectiveBaseUrl}/forecasts/student/$studentId';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  // -- Anomaly detection (Layer 3) -----------------------------
  static Future<Map<String, dynamic>> getAnomalies() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/anomalies'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getAtRisk({String? classId, String? riskLevel}) async {
    var url = '${ApiService.effectiveBaseUrl}/analytics/at-risk';
    final params = <String>[];
    if (classId != null)   params.add('class_id=$classId');
    if (riskLevel != null) params.add('risk_level=$riskLevel');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getClassPerformance(String classId, {String? termId}) async {
    var url = '${ApiService.effectiveBaseUrl}/analytics/class/$classId/performance';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getNotifications({String? studentId}) async {
    var url = '${ApiService.effectiveBaseUrl}/analytics/notifications';
    if (studentId != null) url += '?student_id=$studentId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  // -- Students ---------------------------------------------
  static Future<Map<String, dynamic>> getTerms() async {
    final res = await http.get(Uri.parse('${ApiService.effectiveBaseUrl}/terms'), headers: await _headers());
    return _parse(res);
  }
  static Future<Map<String, dynamic>> getSubjects() async {
    final res = await http.get(Uri.parse('${ApiService.effectiveBaseUrl}/subjects'), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createSubject({required String name, required String level}) async {
    final res = await http.post(Uri.parse('${ApiService.effectiveBaseUrl}/subjects'),
      headers: await _headers(), body: jsonEncode({'name': name, 'level': level}));
    return _parse(res);
  }
  static Future<Map<String, dynamic>> createClass({required String name, required String level}) async {
    final res = await http.post(Uri.parse('${ApiService.effectiveBaseUrl}/classes-create'),
      headers: await _headers(), body: jsonEncode({'name': name, 'level': level}));
    return _parse(res);
  }
  static Future<Map<String, dynamic>> getSchoolTeachers() async {
    final res = await http.get(Uri.parse('${ApiService.effectiveBaseUrl}/school-teachers'), headers: await _headers());
    return _parse(res);
  }
  static Future<Map<String, dynamic>> assignTeacher({required String classId, required String subjectId, required String teacherId, required String termId}) async {
    final res = await http.post(Uri.parse('${ApiService.effectiveBaseUrl}/assign-teacher'),
      headers: await _headers(),
      body: jsonEncode({'class_id': classId, 'subject_id': subjectId, 'teacher_id': teacherId, 'term_id': termId}));
    return _parse(res);
  }
  static Future<Map<String, dynamic>> getStudents({String? classId, String? search}) async {
    var url = '${ApiService.effectiveBaseUrl}/students';
    final params = <String>[];
    if (classId != null) params.add('class_id=$classId');
    if (search != null)  params.add('search=$search');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  // Admin: list classes in own school (to pick when adding a student)
  static Future<Map<String, dynamic>> getClasses() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/classes'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // Admin: create a new student
  static Future<Map<String, dynamic>> createStudent({
    required String classId, required String name, required String gender,
    String? dateOfBirth, String? parentId,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/students'),
      headers: await _headers(),
      body: jsonEncode({
        'class_id': classId, 'name': name, 'gender': gender,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (parentId != null) 'parent_id': parentId,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudent(String id) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/students/$id'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentQR(String id) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/students/$id/qr'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentAttendance(String studentId, {String? termId}) async {
    var url = '${ApiService.effectiveBaseUrl}/attendance/student/$studentId';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentReport(String studentId, {String? termId}) async {
    var url = '${ApiService.effectiveBaseUrl}/marks/student/$studentId';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  // -- Attendance -------------------------------------------
  static Future<Map<String, dynamic>> createSession({
    required String classId,
    required String subjectId,
    required String termId,
    required String sessionDate,
    required int periodNumber,
    DateTime? biometricVerifiedAt,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/attendance/sessions'),
      headers: await _headers(),
      body: jsonEncode({
        'class_id': classId,
        'subject_id': subjectId,
        'term_id': termId,
        'session_date': sessionDate,
        'period_number': periodNumber,
        if (biometricVerifiedAt != null)
          'biometric_verified_at': biometricVerifiedAt.toIso8601String(),
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> scanQR(String sessionId, String qrData) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/attendance/scan'),
      headers: await _headers(),
      body: jsonEncode({'session_id': sessionId, 'qr_data': qrData}),
    );
    return _parse(res);
  }

  /// Pushes a batch of offline-queued scans (see local_db_service.dart /
  /// sync_service.dart) to POST /api/attendance/scan/batch in one call.
  static Future<Map<String, dynamic>> syncScanBatch(List<Map<String, dynamic>> scans) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/attendance/scan/batch'),
      headers: await _headers(),
      body: jsonEncode({'scans': scans}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> closeSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/attendance/sessions/$sessionId/close'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getSessionRecords(String sessionId) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/attendance/sessions/$sessionId/records'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // -- Marks ------------------------------------------------
  static Future<Map<String, dynamic>> getAssessments({String? classId, String? termId}) async {
    var url = '${ApiService.effectiveBaseUrl}/marks/assessments';
    final params = <String>[];
    if (classId != null) params.add('class_id=$classId');
    if (termId != null)  params.add('term_id=$termId');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getMyClasses() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/teacher/my-classes'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> createAssessment({
    required String classId, required String subjectId, required String termId,
    required String name, required String type,
    required double maxScore, required String date, String? description,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/marks/assessments'),
      headers: await _headers(),
      body: jsonEncode({
        'class_id': classId, 'subject_id': subjectId, 'term_id': termId,
        'assessment_name': name, 'assessment_type': type,
        'max_score': maxScore, 'assessment_date': date,
        if (description != null) 'description': description,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getMarksSheet(String assessmentId) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/marks/assessments/$assessmentId/marks'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // Submit a whole mark sheet. [biometricVerifiedAt] is the moment the
  // teacher's fingerprint check succeeded - the backend stores it on the
  // assessment and seals the submission onto the blockchain ledger.
  static Future<Map<String, dynamic>> bulkUpdateMarks({
    required String assessmentId,
    required List<Map<String, dynamic>> marks,
    DateTime? biometricVerifiedAt,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiService.effectiveBaseUrl}/marks/assessments/$assessmentId/bulk'),
      headers: await _headers(),
      body: jsonEncode({
        'marks': marks,
        if (biometricVerifiedAt != null)
          'biometric_verified_at': biometricVerifiedAt.toIso8601String(),
      }),
    );
    return _parse(res);
  }

  // Verify an assessment's marks against what was sealed on the blockchain.
  static Future<Map<String, dynamic>> verifyAssessment(String assessmentId) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/blockchain/verify/assessment/$assessmentId'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // -- Admin Management: Teachers ------------------------------
  static Future<Map<String, dynamic>> adminGetTeachers() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/teachers'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminTeacherImpact(String teacherId) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/teachers/$teacherId/impact'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminUnassignTeacher(String assignmentId) async {
    final res = await http.put(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/assignments/$assignmentId/unassign'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminDeleteTeacher(String teacherId) async {
    final res = await http.delete(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/teachers/$teacherId'),
      headers: await _headers());
    return _parse(res);
  }

  // -- Admin Management: Students ------------------------------
  static Future<Map<String, dynamic>> adminMoveStudent(String studentId, String destinationClassId) async {
    final res = await http.put(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/students/$studentId/move'),
      headers: await _headers(),
      body: jsonEncode({'destination_class_id': destinationClassId}));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminArchiveStudent(String studentId) async {
    final res = await http.put(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/students/$studentId/archive'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminReactivateStudent(String studentId) async {
    final res = await http.put(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/students/$studentId/reactivate'),
      headers: await _headers());
    return _parse(res);
  }

  // -- Admin Management: Parents -------------------------------
  static Future<Map<String, dynamic>> adminGetParents() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/parents'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminReassignParent(String parentId, String studentCode) async {
    final res = await http.put(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/parents/$parentId/reassign'),
      headers: await _headers(),
      body: jsonEncode({'student_code': studentCode}));
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminParentImpact(String parentId) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/parents/$parentId/impact'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminDeleteParent(String parentId) async {
    final res = await http.delete(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/parents/$parentId'),
      headers: await _headers());
    return _parse(res);
  }

  // -- Admin Management: Classes -------------------------------
  static Future<Map<String, dynamic>> adminClassImpact(String classId) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/classes/$classId/impact'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminDeleteClass(String classId) async {
    final res = await http.delete(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/classes/$classId'),
      headers: await _headers());
    return _parse(res);
  }

  // -- Admin Management: Subjects ------------------------------
  static Future<Map<String, dynamic>> adminSubjectImpact(String subjectId) async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/subjects/$subjectId/impact'),
      headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> adminDeleteSubject(String subjectId) async {
    final res = await http.delete(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/subjects/$subjectId'),
      headers: await _headers());
    return _parse(res);
  }

  // -- Admin Management: Audit Log -----------------------------
  static Future<Map<String, dynamic>> adminAuditLog() async {
    final res = await http.get(
      Uri.parse('${ApiService.effectiveBaseUrl}/admin/audit-log'),
      headers: await _headers());
    return _parse(res);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
