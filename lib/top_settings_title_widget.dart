import 'package:flutter/material.dart';
import 'package:clouddflutter/settings_page.dart';

class TopSettingsTitleWidget extends StatelessWidget {
  final bool showCloudd;
  final bool showSettings;
  final bool showNotifications;
  final bool showDDHub;
  final bool showManageExperiences;
  final String clouddText;
  final String notificationsText;
  final String ddHubText;
  final String manageExperiencesText;
  final double logoFontSize;
  final VoidCallback? onSettingsTap;

  const TopSettingsTitleWidget({
    Key? key,
    this.showCloudd = true,
    this.showDDHub = false,
    this.showSettings = true,
    this.showNotifications = false,
    this.showManageExperiences = false,
    this.clouddText = 'CLOUDD',
    this.ddHubText = 'DD Hub',
    this.notificationsText = 'Notifications',
    this.manageExperiencesText = 'Manage Experiences',
    this.logoFontSize = 26,
    this.onSettingsTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logoColor = Theme.of(context).primaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        showCloudd
            ? Text(
                clouddText,
                style: TextStyle(
                  fontSize: logoFontSize,
                  fontWeight: FontWeight.w700,
                  color: logoColor,
                ),
              )
            : showNotifications
            ? Text(
                notificationsText,
                style: TextStyle(
                  fontSize: logoFontSize,
                  fontWeight: FontWeight.w700,
                  color: logoColor,
                ),
              )
            : showDDHub
            ? Text(
                ddHubText,
                style: TextStyle(
                  fontSize: logoFontSize,
                  fontWeight: FontWeight.w700,
                  color: logoColor,
                ),
              )
            : showManageExperiences
            ? Text(
                manageExperiencesText,
                style: TextStyle(
                  fontSize: logoFontSize,
                  fontWeight: FontWeight.w700,
                  color: logoColor,
                ),
              )
            : SizedBox(width: logoFontSize * 3),
        showSettings
            ? IconButton(
                onPressed:
                    onSettingsTap ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    },
                icon: const Icon(Icons.settings, size: 30),
              )
            : const SizedBox(width: 30, height: 48),
      ],
    );
  }
}
