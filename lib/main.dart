import 'package:cloudd_flutter/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:cloudd_flutter/login_page.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
 await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );
  
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    )
  );
}
