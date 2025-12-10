import 'package:clouddflutter/top_settings_title_widget.dart';
import 'package:flutter/material.dart';
import 'package:clouddflutter/manager/widgets/bottom_navigation_widget.dart';

class ManagerAccountPage extends StatelessWidget {
  const ManagerAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopSettingsTitleWidget(showCloudd: false, showSettings: true),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile icon
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Icon(
                      Icons.person,
                      size: 70,
                      color: Theme.of(
                        context,
                      ).iconTheme.color?.withOpacity(0.6),
                    ),
                  ),

                  const SizedBox(width: 15),

                  // User info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "User1234",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Organization",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Joined XX Month, 20XX",
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),
                ],
              ),

              const SizedBox(height: 30),

              // Display Collection Header
              const Text(
                "Display Collection",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              // Display Collection Row
              Row(
                children: [
                  _displayBox(context),
                  const SizedBox(width: 10),
                  _displayBox(context),
                  const SizedBox(width: 10),
                  _displayBox(context),
                  const SizedBox(width: 10),

                  // See All
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "See All",
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Experiences header
              const Text(
                "Experiences",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        context: context,
        onIconTap: (index) {},
      ),
    );
  }

  // Small grey display boxes
  Widget _displayBox(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
