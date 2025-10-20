import 'package:ekit_app/pages/homepage.dart';
import 'package:ekit_app/pages/introPage.dart';
import 'package:ekit_app/pages/notecategory.dart';
import 'package:ekit_app/pages/recordpage.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IntroPage(),
      routes: {
        '/intro': (context) => IntroPage(),
        '/home': (context) => HomePage(),
        '/record': (context) => RecordPage(),
        '/categories': (context) => CategoryPage(),
      },
    );
  }
}
