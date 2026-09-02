import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  static const String _tokenKey = 'sapms_token';
  static const String _userKey  = 'sapms_user';

  // ── Token Management ─────────────────────────────────────
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

  // ── HTTP Helpers ─────────────────────────────────────────
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

  // ── Auth ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login'),
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
      Uri.parse('${AppConstants.baseUrl}/auth/me'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // ── Analytics ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard({String? termId}) async {
    var url = '${AppConstants.baseUrl}/analytics/dashboard';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getAtRisk({String? classId, String? riskLevel}) async {
    var url = '${AppConstants.baseUrl}/analytics/at-risk';
    final params = <String>[];
    if (classId != null)   params.add('class_id=$classId');
    if (riskLevel != null) params.add('risk_level=$riskLevel');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getClassPerformance(String classId, {String? termId}) async {
    var url = '${AppConstants.baseUrl}/analytics/class/$classId/performance';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getNotifications({String? studentId}) async {
    var url = '${AppConstants.baseUrl}/analytics/notifications';
    if (studentId != null) url += '?student_id=$studentId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  // ── Students ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> getStudents({String? classId, String? search}) async {
    var url = '${AppConstants.baseUrl}/students';
    final params = <String>[];
    if (classId != null) params.add('class_id=$classId');
    if (search != null)  params.add('search=$search');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudent(String id) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/students/$id'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentQR(String id) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/students/$id/qr'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentAttendance(String studentId, {String? termId}) async {
    var url = '${AppConstants.baseUrl}/attendance/student/$studentId';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getStudentReport(String studentId, {String? termId}) async {
    var url = '${AppConstants.baseUrl}/marks/student/$studentId';
    if (termId != null) url += '?term_id=$termId';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  // ── Attendance ───────────────────────────────────────────
  static Future<Map<String, dynamic>> createSession({
    required String classId,
    required String subjectId,
    required String termId,
    required String sessionDate,
    required int periodNumber,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/attendance/sessions'),
      headers: await _headers(),
      body: jsonEncode({
        'class_id': classId,
        'subject_id': subjectId,
        'term_id': termId,
        'session_date': sessionDate,
        'period_number': periodNumber,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> scanQR(String sessionId, String qrData) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/attendance/scan'),
      headers: await _headers(),
      body: jsonEncode({'session_id': sessionId, 'qr_data': qrData}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> closeSession(String sessionId) async {
    final res = await http.post(
      Uri.parse('${AppConstants.baseUrl}/attendance/sessions/$sessionId/close'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getSessionRecords(String sessionId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/attendance/sessions/$sessionId/records'),
      headers: await _headers(),
    );
    return _parse(res);
  }

  // ── Marks ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAssessments({String? classId, String? termId}) async {
    var url = '${AppConstants.baseUrl}/marks/assessments';
    final params = <String>[];
    if (classId != null) params.add('class_id=$classId');
    if (termId != null)  params.add('term_id=$termId');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final res = await http.get(Uri.parse(url), headers: await _headers());
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getMarksSheet(String assessmentId) async {
    final res = await http.get(
      Uri.parse('${AppConstants.baseUrl}/marks/assessments/$assessmentId/marks'),
      headers: await _headers(),
    );
    return _parse(res);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
