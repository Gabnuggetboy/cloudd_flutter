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

  final List<String> categories = [
    "Adventure",
    "Relaxation",
    "Entertainment",
    "Learning",
    "Wellness",
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
    enabled = data["enabled"];

    setState(() {});
  }

  Future<void> _save() async {
    final ref = FirebaseFirestore.instance.collection("Experiences");

    if (editing) {
      await ref.doc(widget.experienceId).update({
        "name": _nameController.text,
        "category": selectedCategory,
        "enabled": enabled,
        "last_updated": Timestamp.now(),
      });
    } else {
      await ref.add({
        "name": _nameController.text,
        "category": selectedCategory,
        "enabled": true,
        "last_updated": Timestamp.now(),
      });
    }

    Navigator.pop(context);
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

            const Spacer(),

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
