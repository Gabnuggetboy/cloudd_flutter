import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clouddflutter/login_page.dart';
import 'package:clouddflutter/theme_provider.dart';
import 'package:clouddflutter/app_theme.dart';

void main() => runApp(
  ChangeNotifierProvider(create: (_) => ThemeProvider(), child: const MyApp()),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: LoginPage(),
        );
      },
    );
  }
}
