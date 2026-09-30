import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/env.dart';

/// The one place that starts Supabase. Every other file uses
/// SupabaseService.client, never Supabase.instance directly.
class SupabaseService {
  SupabaseService._();

  static bool _ready = false;

  /// False if env.json is missing or startup failed. The offline parts of
  /// the app (scanner, history) keep working either way.
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (!Env.isConfigured) {
      debugPrint(
        'Supabase is not configured. '
        'Run with --dart-define-from-file=env.json',
      );
      return;
    }
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseKey, // accepts the sb_publishable_ key
      );
      _ready = true;
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
