import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthStateController extends ChangeNotifier {
  AuthStateController({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client {
    _session = _client.auth.currentSession;
    _subscription = _client.auth.onAuthStateChange.listen((state) {
      _session = state.session;
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _subscription;
  Session? _session;

  Session? get session => _session;
  bool get isSignedIn => _session != null;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
