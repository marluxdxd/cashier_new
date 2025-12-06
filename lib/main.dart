import 'package:cashier/view/home.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with your URL and anon key
  await Supabase.initialize(
    url: 'https://fzllmarnhzdhleoqopsx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6bGxtYXJuaHpkaGxlb3FvcHN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwMDM5MjEsImV4cCI6MjA4MDU3OTkyMX0.t77W7a2Aw5PCMpXtYUBBwBVOqlvwsnNiXHDTmRtcavU',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Home(),
    );
  }
}
