import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/constants.dart';

/// Lets any logged-in user change the backend URL without a rebuild.
/// Accessible from the login screen (gear icon) so the IP can be updated
/// before login when the tethering address changes.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});
  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _msg;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    // Show current effective URL (may have been loaded from prefs)
    _ctrl.text = ApiService.effectiveBaseUrl
        .replaceAll('/api', '')   // show just the host:port part
        ;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    setState(() { _saving = true; _msg = null; });
    try {
      await ApiService.saveUrl(raw);
      setState(() {
        _success = true;
        _msg = 'Server URL saved.\nNow: ${ApiService.effectiveBaseUrl}\n\n'
               'Go back and sign in. If it still can\'t connect, make sure the '
               'backend is running and the phone shares the PC\'s network.';
      });
    } catch (e) {
      setState(() { _success = false; _msg = 'Could not save the URL. Please try again.'; });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    await ApiService.resetUrl();
    setState(() {
      _ctrl.text = AppConstants.baseUrl.replaceAll('/api', '');
      _success = true;
      _msg = 'Reset to default: ${AppConstants.baseUrl}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.bgColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Server Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Backend Server URL',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
            'Enter the IP address and port of your SAPMS backend.\n'
            'Example:  http://10.169.211.32:5000\n'
            'The /api path is added automatically.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://10.x.x.x:5000',
              prefixIcon: const Icon(Icons.dns_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
                label: const Text('Save & Use'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          if (_msg != null) ...[ 
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_success ? Colors.green : Colors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_success ? Colors.green : Colors.red).withValues(alpha: 0.4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_success ? Icons.check_circle_outline : Icons.error_outline,
                  color: _success ? Colors.green : Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_msg!,
                  style: TextStyle(
                    color: _success ? Colors.green.shade800 : Colors.red.shade800,
                    fontSize: 13, height: 1.4))),
              ]),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('How to find your PC IP address',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              const Text(
                '1. Open PowerShell on the PC\n'
                '2. Run:  ipconfig | Select-String "IPv4"\n'
                '3. Use the address starting with 10. or 192.168.\n'
                '4. Make sure your phone uses the PC as hotspot/USB tether\n'
                '5. Make sure the backend is running (npm run dev)',
                style: TextStyle(fontSize: 12, height: 1.6, color: Colors.black87)),
            ]),
          ),
        ]),
      ),
    );
  }
}
