import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';

class WorkInProgressPage extends StatefulWidget {
  const WorkInProgressPage({super.key});

  @override
  State<WorkInProgressPage> createState() => _WorkInProgressPageState();
}

class _WorkInProgressPageState extends State<WorkInProgressPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false, // ---> Removes back button
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colors.onSurface,
        title: Text(
          "Coming Soon",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon / Illustration
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 31),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.construction_rounded,
                  size: 64,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                "Work in Progress",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                "We're actively building this feature.\nCheck back soon for something awesome!",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: 179),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),

              // Progress indicator
              Column(
                children: [
                  LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Development in progress",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 153),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),
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
}
