package rw.ac.uok.sapms.sapms_app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth shows its biometric prompt via a Fragment, so MainActivity
// must extend FlutterFragmentActivity instead of the default FlutterActivity.
class MainActivity : FlutterFragmentActivity()
