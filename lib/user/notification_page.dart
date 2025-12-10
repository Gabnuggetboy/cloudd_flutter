import 'package:flutter/material.dart';
import 'package:clouddflutter/user/widgets/bottom_navigation_widget.dart';
import 'package:clouddflutter/top_settings_title_widget.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TopSettingsTitleWidget(
                showCloudd: false,
                showSettings: true,
                showNotifications: true,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 10),
                  NotificationItem(time: "17:59"),
                  NotificationItem(time: "09:01"),
                  NotificationItem(time: "Tues"),
                  NotificationItem(time: "Mon"),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      "No more notifications.",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        context: context,
        onIconTap: (index) {},
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  final String time;

  const NotificationItem({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 14),

          // Message Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Message Title",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. "
                  "Cras ut feugiat lacus.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Timestamp
          Text(
            time,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
