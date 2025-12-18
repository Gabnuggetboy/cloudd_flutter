import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/top_settings_title_widget.dart';

class TradingPage extends StatelessWidget {
  const TradingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              TopSettingsTitleWidget(showCloudd: true, showSettings: true),

              const SizedBox(height: 20),

              // Your Collection title
              const Text(
                "Your Collection",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              // Your Collection row
              SizedBox(
                height: 110,
                child: Row(
                  children: [
                    _collectionBox(context),
                    const SizedBox(width: 10),
                    _collectionBox(context),
                    const SizedBox(width: 10),
                    _collectionBox(context),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "See All",
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search for...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Browse title
              const Text(
                "Browse",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              // Browse Grid (up to 8 boxes)
              GridView.builder(
                physics:
                    const NeverScrollableScrollPhysics(), // prevents nested scroll
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: 8, // change as needed
                itemBuilder: (context, index) {
                  return _browseBox(context);
                },
              ),
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

  // --- Widgets ---

  Widget _collectionBox(BuildContext context) {
    return Container(
      width: 80,
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _browseBox(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
