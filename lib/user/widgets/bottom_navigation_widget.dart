import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/notification_page.dart';
import 'package:cloudd_flutter/user/home_page.dart';
import 'package:cloudd_flutter/user/trading_page.dart';
import 'package:cloudd_flutter/user/user_account_page.dart';
// import 'package:cloudd_flutter/user/camera_page.dart';
import 'package:cloudd_flutter/user/work_in_progress.dart';
import 'package:cloudd_flutter/user/mindar_page.dart';

class BottomNavigationWidget extends StatefulWidget {
  final Function(int)? onIconTap;
  final BuildContext context;
  final double homeIconSize;
  final double tradingIconSize;
  // final double cameraIconSize;
  final double notificationIconSize;
  final double accountIconSize;
  final String homeLabel;
  final String tradingLabel;
  // final String cameraLabel;
  final String notificationLabel;
  final String accountLabel;

  const BottomNavigationWidget({
    super.key,
    this.onIconTap,
    required this.context,
    this.homeIconSize = 45,
    this.tradingIconSize = 45,
    // this.cameraIconSize = 45,
    this.notificationIconSize = 45,
    this.accountIconSize = 45,
    this.homeLabel = 'Home',
    this.tradingLabel = 'Trading',
    // this.cameraLabel = 'Camera',
    this.notificationLabel = 'Notifications',
    this.accountLabel = 'Account',
  });

  @override
  State<BottomNavigationWidget> createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  late int _selectedIndex;

  int _initialIndexFromContext(BuildContext ctx) {
    final type = ctx.widget.runtimeType;
    if (type == HomePage) return 0;
    if (type == TradingPage) return 1;
    // if (type == CameraPage) return 2;
    if (type == NotificationsPage) return 3;
    if (type == AccountPage) return 4;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = _initialIndexFromContext(widget.context);
  }

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    widget.onIconTap?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _selectedIndex == 0 ? Icons.home : Icons.home_outlined,
                    size: widget.homeIconSize,
                  ),
                  onPressed: () {
                    _onTap(0);
                    // Only navigate if not already on HomePage
                    if (widget.context.widget.runtimeType != HomePage) {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const HomePage(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    }
                  },
                ),
                Text(
                  widget.homeLabel,
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
                  icon: Icon(
                    _selectedIndex == 1 ? Icons.search : Icons.search_outlined,
                    size: widget.tradingIconSize,
                  ),
                  onPressed: () {
                    _onTap(1);
                    // Only navigate if not already on TradingPage [NOW WORK IN PROGRESS PAGE]
                    if (widget.context.widget.runtimeType != WorkInProgressPage) {
                      // Navigator.pushReplacement(
                      //   context,
                      //   PageRouteBuilder(
                      //     pageBuilder:
                      //         (context, animation, secondaryAnimation) =>
                      //             const WorkInProgressPage(),
                      //     transitionDuration: Duration.zero,
                      //     reverseTransitionDuration: Duration.zero,
                      //   ),
                      // );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MindARPage()),
                      );
                    }
                  },
                ),
                Text(
                  widget.tradingLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
            // Column(
            //   mainAxisSize: MainAxisSize.min,
            //   children: [
            //     IconButton(
            //       icon: Icon(
            //         _selectedIndex == 2
            //             ? Icons.camera_alt
            //             : Icons.camera_alt_outlined,
            //         size: widget.cameraIconSize,
            //       ),
            //       onPressed: () {
            //         _onTap(2);
            //         Navigator.push(
            //           context,
            //           MaterialPageRoute(
            //             builder: (context) => const CameraPage(),
            //           ),
            //         );
            //       },
            //     ),
            //     Text(
            //       widget.cameraLabel,
            //       style: TextStyle(
            //         fontSize: 12,
            //         color: Theme.of(context).textTheme.bodyMedium?.color,
            //       ),
            //     ),
            //   ],
            // ),
            // Column(
            //   mainAxisSize: MainAxisSize.min,
            //   children: [
            //     IconButton(
            //       icon: Icon(
            //         _selectedIndex == 3
            //             ? Icons.notifications
            //             : Icons.notifications_outlined,
            //         size: widget.notificationIconSize,
            //       ),
            //       onPressed: () {
            //         _onTap(3);
            //         // Only navigate if not already on NotificationsPage [NOW WORK IN PROGRESS PAGE]
            //         if (widget.context.widget.runtimeType !=
            //             WorkInProgressPage) {
            //           Navigator.pushReplacement(
            //             context,
            //             PageRouteBuilder(
            //               pageBuilder:
            //                   (context, animation, secondaryAnimation) =>
            //                       const WorkInProgressPage(),
            //               transitionDuration: Duration.zero,
            //               reverseTransitionDuration: Duration.zero,
            //             ),
            //           );
            //         }
            //       },
            //     ),
            //     Text(
            //       widget.notificationLabel,
            //       style: TextStyle(
            //         fontSize: 12,
            //         color: Theme.of(context).textTheme.bodyMedium?.color,
            //       ),
            //     ),
            //   ],
            // ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _selectedIndex == 4 ? Icons.person : Icons.person_outline,
                    size: widget.accountIconSize,
                  ),
                  onPressed: () {
                    _onTap(4);
                    // Only navigate if not already on AccountPage
                    if (widget.context.widget.runtimeType != AccountPage) {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const AccountPage(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    }
                  },
                ),
                Text(
                  widget.accountLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
