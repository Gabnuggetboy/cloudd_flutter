import 'package:flutter/material.dart';
import 'package:clouddflutter/user/notification_page.dart';
import 'package:clouddflutter/user/home_page.dart';
import 'package:clouddflutter/user/trading_page.dart';
import 'package:clouddflutter/user/user_account_page.dart';

class BottomNavigationWidget extends StatelessWidget {
  final Function(int)? onIconTap;
  final BuildContext context;
  final double homeIconSize;
  final double tradingIconSize;
  final double cameraIconSize;
  final double notificationIconSize;
  final double accountIconSize;
  final String homeLabel;
  final String tradingLabel;
  final String cameraLabel;
  final String notificationLabel;
  final String accountLabel;

  const BottomNavigationWidget({
    Key? key,
    this.onIconTap,
    required this.context,
    this.homeIconSize = 40,
    this.tradingIconSize = 40,
    this.cameraIconSize = 40,
    this.notificationIconSize = 40,
    this.accountIconSize = 40,
    this.homeLabel = 'Home',
    this.tradingLabel = 'Trading',
    this.cameraLabel = 'Camera',
    this.notificationLabel = 'Notifications',
    this.accountLabel = 'Account',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get current route name
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.home, size: homeIconSize),
                onPressed: () {
                  onIconTap?.call(0);
                  // Only navigate if not already on HomePage
                  if (context.widget.runtimeType != HomePage) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const HomePage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              Text(homeLabel, style: TextStyle(fontSize: 12)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.search, size: tradingIconSize),
                onPressed: () {
                  onIconTap?.call(2);
                  // Only navigate if not already on TradingPage
                  if (context.widget.runtimeType != TradingPage) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const TradingPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              Text(tradingLabel, style: TextStyle(fontSize: 12)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.camera_alt, size: cameraIconSize),
                onPressed: () {
                  // onIconTap?.call(2);
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => const TradingPage()),
                  // );
                },
              ),
              Text(cameraLabel, style: TextStyle(fontSize: 12)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.notifications, size: notificationIconSize),
                onPressed: () {
                  onIconTap?.call(3);
                  // Only navigate if not already on NotificationsPage
                  if (context.widget.runtimeType != NotificationsPage) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const NotificationsPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              Text(notificationLabel, style: TextStyle(fontSize: 12)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.person, size: accountIconSize),
                onPressed: () {
                  onIconTap?.call(4);
                  // Only navigate if not already on AccountPage
                  if (context.widget.runtimeType != AccountPage) {
                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const AccountPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    );
                  }
                },
              ),
              Text(accountLabel, style: TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
