import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_icubecontent_page.dart';
import 'add_irigcontent_page.dart';

class ExperienceDetailsPage extends StatefulWidget {
  final String? experienceId;

  const ExperienceDetailsPage({super.key, required this.experienceId});

  @override
  State<ExperienceDetailsPage> createState() => _ExperienceDetailsPageState();
}

class _ExperienceDetailsPageState extends State<ExperienceDetailsPage> {
  final TextEditingController _nameController = TextEditingController();
  List<Map<String, dynamic>> booths = [];

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
    enabled = data["enabled"];
    if (data["booths"] != null) {
      booths = List<Map<String, dynamic>>.from(data["booths"]);
    }

    setState(() {});
  }

  Future<void> _save() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an experience name."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }

    final ref = FirebaseFirestore.instance.collection("Experiences");

    if (editing) {
      await ref.doc(widget.experienceId).update({
        "name": _nameController.text,
        "enabled": enabled,
        "last_updated": Timestamp.now(),
        "booths": booths,
      });
    } else {
      await ref.add({
        "name": _nameController.text,
        "enabled": true,
        "managerId": currentUser.uid,
        "last_updated": Timestamp.now(),
        "booths": booths,
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
            "Are you sure you want to delete this experience?",
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
              child: const Text("Yes", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _addBooth(String device, {String? contentName}) {
    setState(() {
      booths.add({"device": device, "contentName": contentName});
    });
  }

  void _removeBooth(int index) {
    setState(() {
      booths.removeAt(index);
    });
  }

  Future<void> _navigateToContentPage(String device) async {
    dynamic result;

    if (device == "iCube") {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => iCubeTestPage(
            selectionMode: true,
            managerId: FirebaseAuth.instance.currentUser?.uid,
            experienceId: widget.experienceId,
          ),
        ),
      );
    } else if (device == "iRig") {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IrigTestPage(
            selectionMode: true,
            managerId: FirebaseAuth.instance.currentUser?.uid,
            experienceId: widget.experienceId,
          ),
        ),
      );
    }

    if (result != null) {
      // Accept either a single String (backwards compatible) or a List<String>
      if (result is String) {
        _addBooth(device, contentName: result);
      } else if (result is List) {
        for (var item in result) {
          if (item is String) {
            _addBooth(device, contentName: item);//
          }
        }
      }
    }
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
              decoration: const InputDecoration(labelText: "Experience Name"),
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Booths",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: booths.isEmpty
                  ? Center(
                      child: Text(
                        "No booths added yet.\nTap a device below to add one.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      itemCount: booths.length,
                      itemBuilder: (context, index) {
                        final booth = booths[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              Icons.device_hub,
                              color: Color.fromRGBO(143, 148, 251, 1),
                            ),
                            title: Text(
                              booth["device"],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: booth["contentName"] != null
                                ? Text(
                                    "Content: ${booth["contentName"]}",
                                    style: TextStyle(fontSize: 12),
                                  )
                                : Text(
                                    "No specific content",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeBooth(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add Booth",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: devices.map((device) {
                      return ElevatedButton(
                        onPressed: () {
                          if (device == "iCube" || device == "iRig") {
                            _navigateToContentPage(device);
                          } else {
                            _addBooth(device);
                          }
                        },
                        child: Text(device),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
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
