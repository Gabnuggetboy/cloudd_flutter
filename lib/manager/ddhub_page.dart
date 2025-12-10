import 'package:flutter/material.dart';
import 'package:clouddflutter/top_settings_title_widget.dart';
import 'package:clouddflutter/manager/widgets/bottom_navigation_widget.dart';

class DDHubPage extends StatefulWidget {
  const DDHubPage({super.key});

  @override
  State<DDHubPage> createState() => _DDHubPageState();
}

class _DDHubPageState extends State<DDHubPage> {
  final TextEditingController _searchController = TextEditingController();

  Widget _buildTile(
    String title, {
    String? subtitle,
    IconData? leadingIcon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: leadingIcon != null
            ? Icon(leadingIcon, color: Colors.black54)
            : null,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.purple),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            TopSettingsTitleWidget(showCloudd: false, showDDHub: true),
            const SizedBox(height: 10),

            // 🔍 Search
            _buildSearchBar(),

            // MultiDD
            _buildTile("MultiDD", leadingIcon: Icons.apps_rounded),

            const SizedBox(height: 10),

            // DD Devices
            const Text(
              "DD Devices",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            _buildTile(
              "icube lv1",
              subtitle: "iCUBE-1234567",
              leadingIcon: Icons.devices_other,
            ),
            _buildTile(
              "drawing lv3",
              subtitle: "iCREATE-1234567",
              leadingIcon: Icons.devices_other,
            ),

            // + Add new DD device
            Opacity(
              opacity: 0.5,
              child: _buildTile(
                "+ Add New DD Device",
                leadingIcon: Icons.add,
                onTap: null,
              ),
            ),

            const SizedBox(height: 10),

            // Custom Activities
            const Text(
              "Custom Activities",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),

            _buildTile("Rock Climbing", leadingIcon: Icons.fitness_center),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        context: context,
        onIconTap: (index) {},
      ),
    );
  }
}
