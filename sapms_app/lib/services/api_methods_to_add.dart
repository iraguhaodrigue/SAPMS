// ═══════════════════════════════════════════════════════════════════════
// ADMIN MANAGEMENT API METHODS
// Add these inside the ApiService class in lib/services/api_service.dart
// (paste them before the closing brace of the class, near the other admin
//  methods). They follow the exact same pattern as getStudents / reviewUser.
// ═══════════════════════════════════════════════════════════════════════

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
