import 'package:flutter/material.dart';
import 'package:clouddflutter/manager/ddhub_page.dart';
import 'package:clouddflutter/manager/experiences_page.dart';
import 'package:clouddflutter/manager/manager_account_page.dart';

class BottomNavigationWidget extends StatelessWidget {
  final Function(int)? onIconTap;
  final BuildContext context;
  final double ddHubIconSize;
  final double experiencesIconSize;
  final double accountIconSize;
  final String ddHubLabel;
  final String experiencesLabel;
  final String accountLabel;

  const BottomNavigationWidget({
    Key? key,
    this.onIconTap,
    required this.context,
    this.ddHubIconSize = 40,
    this.experiencesIconSize = 40,
    this.accountIconSize = 40,
    this.ddHubLabel = 'DD Hub',
    this.experiencesLabel = 'Experiences',
    this.accountLabel = 'Account',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get current route name
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Image.asset(
                  'assets/images/ddhub_icon.png',
                  width: ddHubIconSize,
                  height: ddHubIconSize,
                ),
                onPressed: () {
                  onIconTap?.call(0);
                  // Only navigate if not already on DDHubPage
                  if (context.widget.runtimeType != DDHubPage) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const DDHubPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              Text(
                ddHubLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Image.asset(
                  'assets/images/experiences_icon.png',
                  width: experiencesIconSize,
                  height: experiencesIconSize,
                ),
                onPressed: () {
                  onIconTap?.call(2);
                  // Only navigate if not already on ExperiencesPage
                  if (context.widget.runtimeType != ExperiencesPage) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ExperiencesPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              Text(
                experiencesLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.person, size: accountIconSize),
                onPressed: () {
                  onIconTap?.call(3);
                  // Only navigate if not already on ManagerAccountPage
                  if (context.widget.runtimeType != ManagerAccountPage) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ManagerAccountPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              Text(
                accountLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
