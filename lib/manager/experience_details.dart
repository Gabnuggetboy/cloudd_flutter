import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_icubecontent_page.dart';
import 'add_irigcontent_page.dart';
import 'add_icreatecontent_page.dart';
import 'add_storytimecontent_page.dart';

class ExperienceDetailsPage extends StatefulWidget {
  final String? experienceId;

  const ExperienceDetailsPage({super.key, required this.experienceId});

  @override
  State<ExperienceDetailsPage> createState() => _ExperienceDetailsPageState();
}

class _ExperienceDetailsPageState extends State<ExperienceDetailsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _collabSearchController = TextEditingController();

  String? category;

  List<Map<String, dynamic>> booths = [];
  List<Map<String, dynamic>> collaborators = [];
  List<Map<String, dynamic>> suggestionResults = [];
  List<Map<String, dynamic>> selectedSuggestions = [];

  final List<String> devices = ["iCube", "iRig", "iCreate", "Storytime"];

  final List<String> categories = [
    "Education",
    "Entertainment",
    "Technology",
    "Art",
    "Workshop",
  ];

  bool enabled = true;
  bool editing = false;

  Timer? _searchDebounce;

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
    category = data["category"];
    enabled = data["enabled"];
    if (data["booths"] != null) {
      booths = List<Map<String, dynamic>>.from(data["booths"]);
    }
    if (data["collaborators"] != null) {
      collaborators = List<Map<String, dynamic>>.from(data["collaborators"]);
    }

    setState(() {});
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        suggestionResults = [];
      });
      return;
    }

    final String end = query + '\uf8ff';
    final List<Map<String, dynamic>> results = [];

    try {
      // Try common user collections
      final managersSnap = await FirebaseFirestore.instance
          .collection('Managers')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: end)
          .limit(10)
          .get();

      for (var d in managersSnap.docs) {
        results.add({'email': d['email'], 'uid': d.id});
      }

      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: end)
          .limit(10)
          .get();

      for (var d in usersSnap.docs) {
        results.add({'email': d['email'], 'uid': d.id});
      }
    } catch (e) {
      // nth
    }

    // To remove collaborators that are already added from the seach bar dropdown
    final emailsSeen = <String>{};
    final filtered = results.where((r) {
      final em = (r['email'] ?? '').toString();
      if (emailsSeen.contains(em)) return false;
      emailsSeen.add(em);
      final already = collaborators.any(
        (c) => c['email'] == em && c['status'] == 'accepted',
      );
      return !already;
    }).toList();

    setState(() {
      suggestionResults = filtered;
    });
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
        "category": category,
        "last_updated": Timestamp.now(),
        "booths": booths,
      });
    } else {
      await ref.add({
        "name": _nameController.text,
        "enabled": true,
        "category": category,
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

  void _toggleSelectSuggestion(Map<String, dynamic> suggestion) {
    final email = suggestion['email'] as String? ?? '';
    final exists = selectedSuggestions.any((s) => s['email'] == email);
    setState(() {
      if (exists) {
        selectedSuggestions.removeWhere((s) => s['email'] == email);
      } else {
        selectedSuggestions.add(suggestion);
      }
    });
  }

  Future<void> _addSelectedCollaborators() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    if (widget.experienceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the experience first')),
      );
      return;
    }

    final ref = FirebaseFirestore.instance
        .collection('Experiences')
        .doc(widget.experienceId);
    final notifRef = FirebaseFirestore.instance.collection('Notifications');

    // Ensure we have latest collaborators
    final doc = await ref.get();
    final data = doc.data();
    List existing = [];
    if (data != null && data['collaborators'] != null)
      existing = List.from(data['collaborators']);

    for (var s in selectedSuggestions) {
      final rawEmail = s['email'] as String? ?? '';
      final email = rawEmail.toLowerCase();
      final uid = s['uid'] as String?;

      // avoid duplicates
      final alreadyPending = existing.any(
        (c) => (c['email'] as String?)?.toLowerCase() == email,
      );
      if (alreadyPending) {
        continue;
      }

      // add to local list with pending
      final entry = {
        'email': email,
        'uid': uid,
        'status': 'pending',
        'invitedBy': currentUser.email?.toLowerCase(),
      };
      existing.add(entry);

      // create notification doc for recipient (store lower-case for matching)
      await notifRef.add({
        'recipientEmail': email,
        'recipientUid': uid,
        'type': 'invite',
        'experienceId': widget.experienceId,
        'experienceName': _nameController.text,
        'fromEmail': currentUser.email?.toLowerCase(),
        'status': 'unread',
        'createdAt': Timestamp.now(),
      });
    }

    // to maintain quick lookup arrays for collaborator uids and emails
    // Only include collaborators whose status is 'accepted'
    final Set<String> collabUids = {};
    final Set<String> collabEmails = {};
    for (var e in existing) {
      final status = (e['status'] as String?) ?? '';
      if (status != 'accepted') continue;
      final uid = (e['uid'] as String?);
      final email = (e['email'] as String?)?.toLowerCase();
      if (uid != null && uid.isNotEmpty) collabUids.add(uid);
      if (email != null && email.isNotEmpty) collabEmails.add(email);
    }

    await ref.update({
      'collaborators': existing,
      'collaboratorUids': collabUids.toList(),
      'collaboratorEmails': collabEmails.toList(),
    });

    // refresh local
    setState(() {
      collaborators = List<Map<String, dynamic>>.from(
        existing.map((e) => Map<String, dynamic>.from(e)),
      );
      selectedSuggestions = [];
      suggestionResults = [];
      _collabSearchController.clear();
    });
  }

  void _removeBooth(int index) {
    setState(() {
      booths.removeAt(index);
    });
  }

  Future<void> _navigateToContentPage(String device) async {
    dynamic result;

    // for initial content selections
    final initialSelections = booths
        .where((b) => (b['device'] == device) && (b['contentName'] != null))
        .map((b) => b['contentName'] as String)
        .toList();

    if (device == "iCube") {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => iCubeTestPage(
            selectionMode: true,
            managerId: FirebaseAuth.instance.currentUser?.uid,
            experienceId: widget.experienceId,
            initialSelectedContents: initialSelections,
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
            initialSelectedContents: initialSelections,
          ),
        ),
      );
    } else if (device == "iCreate") {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => iCreateTestPage(
            selectionMode: true,
            managerId: FirebaseAuth.instance.currentUser?.uid,
            experienceId: widget.experienceId,
            initialSelectedContents: initialSelections,
          ),
        ),
      );
    } else if (device == "Storytime") {
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoryTimeTestPage(
            selectionMode: true,
            managerId: FirebaseAuth.instance.currentUser?.uid,
            experienceId: widget.experienceId,
            initialSelectedContents: initialSelections,
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
            _addBooth(device, contentName: item); //
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Experience Name"),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                items: categories.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    category = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              if (editing) ...[
                // Add Collaborator section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Add Collaborator",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
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
                      const Text(
                        "Add collaborators to this event",
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _collabSearchController,
                        decoration: const InputDecoration(
                          hintText: "Find collaborators",
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              _searchUsers(value.trim().toLowerCase());
                            },
                          );
                        },
                      ),

                      // suggestions dropdown
                      if (suggestionResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: BoxConstraints(maxHeight: 160),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestionResults.length,
                            itemBuilder: (context, idx) {
                              final s = suggestionResults[idx];
                              final email = s['email'] ?? '';
                              final selected = selectedSuggestions.any(
                                (e) => e['email'] == email,
                              );
                              return ListTile(
                                tileColor: selected
                                    ? Colors.green.shade50
                                    : null,
                                title: Text(email),
                                subtitle: const Text("Invite as collaborator"),
                                onTap: () => _toggleSelectSuggestion(s),
                                trailing: selected
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: selectedSuggestions.isEmpty
                                ? null
                                : _addSelectedCollaborators,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedSuggestions.isEmpty
                                  ? Colors.grey
                                  : null,
                            ),
                            child: const Text('Add To Experience'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Collaborators box
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
                      const Text(
                        'Collaborators',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (collaborators.isEmpty)
                        const Text(
                          'No collaborators yet.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Column(
                          children: collaborators.map((c) {
                            final status = c['status'] ?? 'pending';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  Icons.person,
                                  color: status == 'accepted'
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                title: Text(c['email'] ?? ''),
                                subtitle: Text(
                                  status == 'pending'
                                      ? 'Pending invite'
                                      : 'Collaborator',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Booths",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 300, // Fixed height for the booths list
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: devices.map((device) {
                        return ElevatedButton(
                          onPressed: () {
                            if (device == "iCube" ||
                                device == "iRig" ||
                                device == "iCreate" ||
                                device == "Storytime") {
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
      ),
    );
  }
}
