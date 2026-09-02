import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';
import '../../utils/locale_controller.dart';
import '../admin/admin_dashboard.dart';
import '../teacher/teacher_home.dart';
import '../parent/parent_home.dart';
import 'register_screen.dart';
import '../settings/server_settings_screen.dart';

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
      // Never expose raw SocketException / ClientException / IP addresses
      final msg = e.toString().toLowerCase();
      String friendly;
      if (msg.contains('socket') || msg.contains('connection') ||
          msg.contains('network') || msg.contains('failed to connect') ||
          msg.contains('failed to fetch')) {
        friendly = 'Unable to connect to the server.\nPlease check your internet connection and try again.';
      } else if (msg.contains('timeout')) {
        friendly = 'The server took too long to respond.\nPlease try again.';
      } else if (msg.contains('invalid credentials') || msg.contains('incorrect')) {
        friendly = 'Incorrect email or password.';
      } else if (msg.contains('pending') || msg.contains('not approved')) {
        friendly = 'Your account is pending approval by the administrator.';
      } else if (msg.contains('inactive') || msg.contains('disabled')) {
        friendly = 'Your account has been deactivated. Please contact your administrator.';
      } else {
        friendly = 'Something went wrong. Please try again later.';
      }
      setState(() { _error = friendly; });
      debugPrint('Login error (debug only): \$e');
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.strings;
    return Scaffold(
      backgroundColor: AppConstants.primaryColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Language picker (top-right) ──────────────
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Server settings — lets user change IP without rebuild
                    IconButton(
                      icon: const Icon(Icons.settings_ethernet_rounded,
                        color: Colors.white54, size: 20),
                      tooltip: 'Server settings',
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                          builder: (_) => const ServerSettingsScreen())),
                    ),
                    _LanguageToggle(),
                  ],
                ),
              ),

              // ── Header ──────────────────────────────────
              const SizedBox(height: 16),
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
              Text(t.t('app_full_name'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              // Version tag — clean, no personal identifiers
              const Text('v2.0.0',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 32),

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
                    const Text('Welcome Back', style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold,
                    )),
                    const SizedBox(height: 4),
                    const Text('Sign in to continue',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: t.t('email_address'),
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
                        labelText: t.t('password'),
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
                          : Text(t.t('sign_in'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Self-registration for teachers & parents
                    Center(child: TextButton(
                      onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text("New teacher or parent? Create an account"),
                    )),
                    const SizedBox(height: 12),


                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('SAPMS © 2025  •  v2.0.0',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// EN / RW segmented toggle. Persists the choice and rebuilds the app.
class _LanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final current = LocaleController.instance.languageCode.value;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langChip(context, 'EN', 'en', current == 'en'),
          _langChip(context, 'RW', 'rw', current == 'rw'),
        ],
      ),
    );
  }

  Widget _langChip(BuildContext context, String label, String code, bool active) {
    return GestureDetector(
      onTap: () => LocaleController.instance.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppConstants.primaryColor : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
