import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../admin/admin_dashboard.dart';
import '../teacher/teacher_home.dart';
import '../parent/parent_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

  // Demo account shortcuts
  final _demoAccounts = [
    {'label': 'Admin',   'email': 'admin.kagano@sapms.rw',   'role': 'admin'},
    {'label': 'Teacher', 'email': 'teacher.math@sapms.rw',   'role': 'teacher'},
    {'label': 'Parent',  'email': 'parent.kamanzi@sapms.rw', 'role': 'parent'},
  ];

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      final role = data['user']['role'];
      if (!mounted) return;
      Widget next;
      switch (role) {
        case 'admin':
        case 'sysadmin': next = const AdminDashboard(); break;
        case 'teacher':  next = const TeacherHome();    break;
        case 'parent':   next = const ParentHome();     break;
        default:         next = const AdminDashboard();
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.primaryColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('SAPMS', style: TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold,
              )),
              const Text('Student Attendance & Performance\nMonitoring System',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('University of Kigali',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40),

              // ── Login Card ───────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sign In', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                    )),
                    const SizedBox(height: 4),
                    const Text('Nyamasheke District Schools',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true, fillColor: AppConstants.bgColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true, fillColor: AppConstants.bgColor,
                      ),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.dangerColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.dangerColor.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: AppConstants.dangerColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                            style: TextStyle(color: AppConstants.dangerColor, fontSize: 13),
                          )),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Demo accounts
                    const Text('Demo Accounts (password: Sapms@2025)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _demoAccounts.map((acc) => ActionChip(
                        label: Text(acc['label']!, style: const TextStyle(fontSize: 12)),
                        avatar: const Icon(Icons.person, size: 16),
                        onPressed: () {
                          _emailCtrl.text    = acc['email']!;
                          _passwordCtrl.text = 'Sapms@2025';
                        },
                      )).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('NSHUTIYIMANA Abraham | Reg: 25012215',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
