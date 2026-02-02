import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final user = _auth.currentUser;

    if (user == null) {
      _isDarkMode = false;
      notifyListeners();
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        _isDarkMode = userDoc.data()?['isDarkMode'] ?? false;
      } else {
        _isDarkMode = false;
      }
    } catch (e) {
      _isDarkMode = false;
    }

    notifyListeners();
  }

  Future<void> refreshThemePreference() async {
    await _loadThemePreference();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _saveThemePreference();
  }

  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();
    await _saveThemePreference();
  }

  Future<void> _saveThemePreference() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isDarkMode': _isDarkMode,
      });
    } catch (e) {
      // nothing
    }
  }
}
