import 'package:cloudd_flutter/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudd_flutter/login_page.dart';
import 'package:cloudd_flutter/theme_provider.dart';
import 'package:cloudd_flutter/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/navigation_service.dart';
import 'package:cloudd_flutter/user/home_page.dart';
import 'package:cloudd_flutter/manager/manager_account_page.dart';
import 'package:cloudd_flutter/models/user.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  // Ensure flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
  );
  debugPrint("AppCheck provider = ${kDebugMode ? "DEBUG" : "PLAY_INTEGRITY"}");
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: NavigationService.navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const AuthWrapper(),
        );
      },
    );
  }
}
// Wrapper widget that listens to Firebase auth state changes
// and redirects users to the appropriate page based on login status
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        // Show loading indicator while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPage();
        }

        final User user = snapshot.data!;

        // Check if email is verified
        if (!user.emailVerified) {
          return const LoginPage();
        }

        // User is logged in and email is verified
        // Fetch user role and redirect accordingly
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            // Show loading while fetching user data
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Error or no data - fallback to login
            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const LoginPage();
            }

            // Refresh theme preference for the logged-in user
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<ThemeProvider>(context, listen: false)
                  .refreshThemePreference();
            });

            final appUser = AppUser.fromDoc(userSnapshot.data!);

            // Redirect based on role
            if (appUser.isManager) {
              return const ManagerAccountPage();
            } else {
              return const HomePage();
            }
          },
        );
      },
    );
  }
}