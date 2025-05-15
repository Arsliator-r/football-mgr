import 'package:flutter/material.dart';
import 'package:football_mgr/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  // debugPaintSizeEnabled = true;
  await Firebase.initializeApp();
  print("NOW RUNNING");
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FlutterApp()));
}

class AppSize{
  static double getHeight(BuildContext context) => MediaQuery.of(context).size.height;

  static double getWidth(BuildContext context) => MediaQuery.of(context).size.width;
}


class FlutterApp extends StatelessWidget{
  const FlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
   return MaterialApp( 
    title: 'My Flutter App',
    theme: ThemeData(
      primarySwatch: Colors.grey,
    ),
    debugShowCheckedModeBanner: false,
    home: const SplashScreen(),
   );
  }
}
