import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

// Self-registration for teachers and parents (agreed design: staff create
// students; sysadmin creates admins). New accounts land in 'pending' and the
// school admin approves them from the Pending Approvals screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _studentCode = TextEditingController();

  String _role = 'parent';
  String? _schoolId;
  List _schools = [];
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    try {
      final res = await ApiService.getSchools();
      setState(() => _schools = res['data'] ?? []);
    } catch (_) {/* dropdown stays empty; teacher flow will show a hint */}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        role: _role,
        schoolId: _role == 'teacher' ? _schoolId : null,
        studentCode: _role == 'parent' ? _studentCode.text.trim() : null,
      );
      if (!mounted) return;
      showDialog(context: context, builder: (_) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_rounded, color: Colors.green, size: 40),
        title: const Text('Registration received'),
        content: Text(res['message'] ?? 'Wait for admin approval, then log in.'),
        actions: [TextButton(
          onPressed: () { Navigator.pop(context); Navigator.pop(context); },
          child: const Text('Back to Sign In'),
        )],
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppConstants.dangerColor,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = _role == 'parent';
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Who are you?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _roleCard('parent', Icons.family_restroom_rounded, 'Parent')),
              const SizedBox(width: 12),
              Expanded(child: _roleCard('teacher', Icons.school_rounded, 'Teacher')),
            ]),
            const SizedBox(height: 6),
            Text(
              isParent
                ? "You'll need your child's student code (printed on their QR card or from the school)."
                : 'Select your school below. The school admin will approve your account.',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 18),

            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 12),

            if (isParent)
              TextFormField(
                controller: _studentCode,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: "Child's student code",
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                  hintText: 'e.g. GSFAK0123',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Student code is required' : null,
              )
            else
              DropdownButtonFormField<String>(
                value: _schoolId,
                decoration: const InputDecoration(labelText: 'Your school', prefixIcon: Icon(Icons.location_city_rounded)),
                items: _schools.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                  value: s['id'], child: Text(s['name'], overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: (v) => setState(() => _schoolId = v),
                validator: (v) => v == null ? 'Select your school' : null,
              ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password (min 8 characters)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure)),
              ),
              validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Register'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _roleCard(String value, IconData icon, String label) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppConstants.primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppConstants.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppConstants.primaryColor : Colors.grey, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppConstants.primaryColor : Colors.black87)),
        ]),
      ),
    );
  }
}
