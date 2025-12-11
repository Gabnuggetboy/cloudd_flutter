import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExperienceDetailsPage extends StatefulWidget {
  final String? experienceId;

  const ExperienceDetailsPage({super.key, required this.experienceId});

  @override
  State<ExperienceDetailsPage> createState() => _ExperienceDetailsPageState();
}

class _ExperienceDetailsPageState extends State<ExperienceDetailsPage> {
  final TextEditingController _nameController = TextEditingController();
  String? selectedCategory;
  String? selectedDevice;

  final List<String> categories = [
    "Adventure",
    "Relaxation",
    "Entertainment",
    "Learning",
    "Wellness",
  ];

  final List<String> devices = [
    "iCube",
    "iRig",
    "iTiles",
    "iCreate",
    "Storytime",
  ];

  bool enabled = true;
  bool editing = false;

  @override
  void initState() {
    super.initState();
    if (widget.experienceId != null) {
      editing = true;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection("Experiences")
        .doc(widget.experienceId)
        .get();

    final data = doc.data()!;
    _nameController.text = data["name"];
    selectedCategory = data["category"];
    selectedDevice = data["devices"];
    enabled = data["enabled"];

    setState(() {});
  }

  Future<void> _save() async {

    if (_nameController.text.trim().isEmpty ||
        selectedCategory == null ||
        selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all fields before continuing."),
          backgroundColor: Colors.red,
        ),
      );
      return; // Stop save
    }

    final ref = FirebaseFirestore.instance.collection("Experiences");

    if (editing) {
      await ref.doc(widget.experienceId).update({
        "name": _nameController.text,
        "category": selectedCategory,
        "device": selectedDevice,
        "enabled": enabled,
        "last_updated": Timestamp.now(),
      });
    } else {
      await ref.add({
        "name": _nameController.text,
        "category": selectedCategory,
        "device": selectedDevice,
        "enabled": true,
        "last_updated": Timestamp.now(),
      });
    }

    Navigator.pop(context);
  }


  Future<void> _deleteExperience() async {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text(
          "Are you sure you want to delete this experience?"
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              // Perform delete
              await FirebaseFirestore.instance
                  .collection("Experiences")
                  .doc(widget.experienceId)
                  .delete();

              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to experiences page
            },
            child: const Text(
              "Yes",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? "Edit Experience" : "New Experience"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(labelText: "Experience Name"),
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(labelText: "Category"),
              items: categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: selectedDevice,
              decoration: const InputDecoration(labelText: "Device"),
              items: devices
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedDevice = value;
                });
              },
            ),

            const Spacer(),
            if (editing)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: _deleteExperience,
                    child: const Text(
                      "Delete",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text("Finished"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
