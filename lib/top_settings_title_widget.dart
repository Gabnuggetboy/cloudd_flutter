import 'package:flutter/material.dart';
import 'package:cloudd_flutter/settings_page.dart';
import 'package:cloudd_flutter/manager/notification_page.dart';

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
  final bool showNotificationIcon;
  final VoidCallback? onNotificationTap;
  final bool showBackArrow;
  final VoidCallback? onBackArrowTap;

  const TopSettingsTitleWidget({
    super.key,
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
    this.showNotificationIcon = false,
    this.onNotificationTap,
    this.showBackArrow = false,
    this.onBackArrowTap,
  });

  @override
  Widget build(BuildContext context) {
    final logoColor = Theme.of(context).primaryColor;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBackArrow)
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: onBackArrowTap ?? () => Navigator.pop(context),
              ),
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
          ],
        ),
        showNotificationIcon
            ? IconButton(
                onPressed:
                    onNotificationTap ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationsPage(),
                        ),
                      );
                    },
                icon: const Icon(Icons.notifications, size: 30),
              )
            : showSettings
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
