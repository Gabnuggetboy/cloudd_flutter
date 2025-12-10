import 'package:flutter/material.dart';
import 'package:cloudd_flutter/user/widgets/bottom_navigation_widget.dart';
import 'package:cloudd_flutter/user/widgets/top_settings_title_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
              TopSettingsTitleWidget(showLogo: true, showSettings: true),

              const SizedBox(height: 10),

              /// Greetings
              const Text(
                "Hi User 1234,",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Text(
                "Find The Best Experiences for You",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 20),

              /// Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search for Experience...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    "Categories",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    "See all",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              /// Category Circles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 65,
                    height: 65,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8E0E0),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              /// Recommended Header
              const Text(
                "Recommended",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 15),

              /// Recommended Boxes
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.42,
                      margin: EdgeInsets.only(
                        right: 15,
                        left: index == 0 ? 0 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8CFCF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/recommended_${index + 1}.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              /// Recently Played Header
              const Text(
                "Recently Played",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 15),

              /// Recently Played Row
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Container(
                      width: MediaQuery.of(context).size.width * 0.42,
                      margin: EdgeInsets.only(
                        right: 15,
                        left: index == 0 ? 0 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8CFCF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/recently_played_${index + 1}.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),
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
