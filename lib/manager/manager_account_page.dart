import 'package:clouddflutter/user/widgets/top_settings_title_widget.dart';
import 'package:flutter/material.dart';
import 'package:clouddflutter/manager/widgets/bottom_navigation_widget.dart';

class ManagerAccountPage extends StatelessWidget {
  const ManagerAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopSettingsTitleWidget( showLogo: false,
              showSettings: true),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile icon
                  const CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.black12,
                    child: Icon(Icons.person, size: 70, color: Colors.black54),
                  ),

                  const SizedBox(width: 15),

                  // User info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "User1234",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text("Organization", style: TextStyle(fontSize: 16)),
                      SizedBox(height: 4),
                      Text(
                        "Joined XX Month, 20XX",
                        style: TextStyle(fontSize: 14, color: Colors.black54),
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
                  _displayBox(),
                  const SizedBox(width: 10),
                  _displayBox(),
                  const SizedBox(width: 10),
                  _displayBox(),
                  const SizedBox(width: 10),

                  // See All
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerRight,
                      child: const Text(
                        "See All",
                        style: TextStyle(
                          color: Colors.black54,
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
  Widget _displayBox() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
