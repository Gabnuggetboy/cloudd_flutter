import 'package:flutter/material.dart';

class DDHubPage extends StatefulWidget {
  const DDHubPage({super.key});

  @override
  State<DDHubPage> createState() => _DDHubPageState();
}

class _DDHubPageState extends State<DDHubPage> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

 Widget buildTile(String title, {Widget? trailing, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Personalization",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            buildTile(
              "Dark Mode",
            ),
            buildTile("Appearance"),
            buildTile("Display Language"),

            const SizedBox(height: 25),

            const Text(
              "Notifications and Activity",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            buildTile(
              "Notifications",
              trailing: Switch(value: false, onChanged: (_) {}),
            ),
            buildTile("Sounds"),
            buildTile("Reminders"),

            const SizedBox(height: 25),

            const Text(
              "Account",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            buildTile("Switch Account"),
            buildTile(
              "Logout",
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

