import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static final supabase = Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
     url: 'https://fzllmarnhzdhleoqopsx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6bGxtYXJuaHpkaGxlb3FvcHN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwMDM5MjEsImV4cCI6MjA4MDU3OTkyMX0.t77W7a2Aw5PCMpXtYUBBwBVOqlvwsnNiXHDTmRtcavU',
  );
  }
}
