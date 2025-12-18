import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudd_flutter/login_page.dart';
import 'package:cloudd_flutter/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/navigation_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> deleteAccount(BuildContext context) async {
  print("DEBUG: Starting account deletion");
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      print("DEBUG: No user found");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No user logged in")),
      );
      return;
    }

    // Delete Firestore data
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .delete();
    print("DEBUG: Firestore document deleted");

    // Delete auth account
    await user.delete();
    print("DEBUG: Auth account deleted");

    // **USE NAVIGATION SERVICE - NO CONTEXT NEEDED**
    print("DEBUG: Navigating with NavigationService");
    NavigationService.pushAndRemoveUntil(LoginPage());
    print("DEBUG: Navigation called");
    
  } catch (e) {
    print("DEBUG: Error: $e");
    
    // Show error using current context (if still valid)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}
  Widget buildTile(
    BuildContext context,
    String title, {
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          "Settings",
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Personalization",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            buildTile(
              context,
              "Dark Mode",
              trailing: Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.setTheme(value);
                },
              ),
            ),
            buildTile(context, "Appearance"),
            buildTile(context, "Display Language"),
            const SizedBox(height: 25),
            Text(
              "Notifications and Activity",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            buildTile(
              context,
              "Notifications",
              trailing: Switch(value: false, onChanged: (_) {}),
            ),
            buildTile(context, "Sounds"),
            buildTile(context, "Reminders"),
            const SizedBox(height: 25),
            Text(
              "Account",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            buildTile(context, "Switch Account"),
            buildTile(
              context,
              "Logout",
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: const Text(
                  "Delete Account",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Delete Account"),
                      content: const Text(
                        "Are you sure you want to permanently delete your account? "
                        "This action cannot be undone.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close popup
                          },
                          child: const Text("No"),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close the confirmation dialog
                            try {
                              await deleteAccount(context);
                              // Navigation happens inside deleteAccount on success
                            } catch (e) {
                              // Error is already handled in deleteAccount
                            }
                          },
                          child: const Text(
                            "Yes",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}
