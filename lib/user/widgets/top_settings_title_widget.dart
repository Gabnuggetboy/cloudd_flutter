import 'package:flutter/material.dart';
import 'package:cloudd_flutter/settings_page.dart';

class TopSettingsTitleWidget extends StatelessWidget {
  final bool showLogo;
  final bool showSettings;
  final bool showNotifications;
  final String logoText;
  final String notificationsText;
  final Color logoColor;
  final double logoFontSize;
  final VoidCallback? onSettingsTap;
  final bool isDarkMode;
  final Function(bool)? onThemeChanged;

  const TopSettingsTitleWidget({
    Key? key,
    this.showLogo = true,
    this.showSettings = true,
    this.showNotifications = false,
    this.logoText = 'CLOUDD',
    this.notificationsText = 'Notifications',
    this.logoColor = const Color(0xFFA020F0),
    this.logoFontSize = 26,
    this.onSettingsTap,
    this.isDarkMode = false,
    this.onThemeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        showLogo
            ? Text(
                logoText,
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
            : SizedBox(width: logoFontSize * 3),
        showSettings
            ? IconButton(
                onPressed:
                    onSettingsTap ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(
                            isDarkMode: isDarkMode,
                            onThemeChanged: onThemeChanged ?? (_) {},
                          ),
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
