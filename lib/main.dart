import 'package:cashier/view/home.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://fzllmarnhzdhleoqopsx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ6bGxtYXJuaHpkaGxlb3FvcHN4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUwMDM5MjEsImV4cCI6MjA4MDU3OTkyMX0.t77W7a2Aw5PCMpXtYUBBwBVOqlvwsnNiXHDTmRtcavU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(

        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Home(),
    );
  }
}




