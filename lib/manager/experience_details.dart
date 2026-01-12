import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/models/notification.dart';
import 'add_icubecontent_page.dart';
import 'add_irigcontent_page.dart';
import 'add_icreatecontent_page.dart';
import 'add_storytimecontent_page.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ExperienceDetailsPage extends StatefulWidget {
  final String? experienceId;

  const ExperienceDetailsPage({super.key, required this.experienceId});

  @override
  State<ExperienceDetailsPage> createState() => _ExperienceDetailsPageState();
}

class _ExperienceDetailsPageState extends State<ExperienceDetailsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _collabSearchController = TextEditingController();

  File? _selectedImage;
  String? _imageUrl;
  bool _uploadingImage = false;

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

  late Experience _currentExperience;

  @override
  void initState() {
    super.initState();
    if (widget.experienceId != null) {
      editing = true;
      _loadData();
    } else {
      _currentExperience = Experience(
        id: '',
        name: '',
        enabled: true,
        booths: [],
        collaborators: [],
        collaboratorUids: [],
        collaboratorEmails: [],
      );
    }
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection("Experiences")
        .doc(widget.experienceId)
        .get();

    if (!doc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Experience not found")));
        Navigator.pop(context);
      }
      return;
    }

    final experience = Experience.fromDoc(doc);
    _currentExperience = experience;

    _nameController.text = experience.name;
    category = experience.category;
    enabled = experience.enabled;
    _imageUrl = experience.imageUrl;
    booths = List<Map<String, dynamic>>.from(experience.booths);
    collaborators = List<Map<String, dynamic>>.from(experience.collaborators);

    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage(String experienceId) async {
    if (_selectedImage == null) return _imageUrl;

    try {
      setState(() => _uploadingImage = true);

      final ref = FirebaseStorage.instance
          .ref()
          .child('experience_images')
          .child('$experienceId.jpg');

      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Image upload failed: $e");
      return null;
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => suggestionResults = []);
      return;
    }

    final String end = '$query\uf8ff';
    final List<Map<String, dynamic>> results = [];

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Manager')
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThan: end)
          .limit(10)
          .get();

      for (var d in usersSnap.docs) {
        if (currentUser != null && d.id == currentUser.uid) continue;
        results.add({'email': d['email'], 'uid': d.id});
      }
    } catch (e) {
      // Silent ignore
    }

    final emailsSeen = <String>{};
    final filtered = results.where((r) {
      final em = (r['email'] ?? '').toString().toLowerCase();
      if (emailsSeen.contains(em)) return false;
      emailsSeen.add(em);

      final alreadyAccepted = collaborators.any(
        (c) =>
            (c['email'] as String?)?.toLowerCase() == em &&
            c['status'] == 'accepted',
      );

      return !alreadyAccepted;
    }).toList();

    setState(() => suggestionResults = filtered);
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

    String experienceId;
    final ref = FirebaseFirestore.instance.collection("Experiences");

    if (editing) {
      experienceId = widget.experienceId!;
    } else {
      final docRef = await FirebaseFirestore.instance
          .collection("Experiences")
          .add(
            _currentExperience
                .copyWith(
                  name: _nameController.text.trim(),
                  category: category,
                  enabled: enabled,
                  booths: booths,
                  creatorId: currentUser.uid,
                  managerId: currentUser.uid,
                  lastUpdated: Timestamp.now(),
                  collaborators: collaborators,
                  collaboratorUids: _currentExperience.collaboratorUids,
                  collaboratorEmails: _currentExperience.collaboratorEmails,
                )
                .toMap(),
          );
      experienceId = docRef.id;
      _currentExperience = _currentExperience.copyWith(id: docRef.id);
    }

    final imageUrl = await _uploadImage(experienceId);

    // Fully update the model using copyWith from the actual class
    _currentExperience = _currentExperience.copyWith(
      name: _nameController.text.trim(),
      category: category,
      enabled: enabled,
      booths: booths,
      creatorId: editing ? _currentExperience.creatorId : currentUser.uid,
      managerId: editing ? _currentExperience.managerId : currentUser.uid,
      lastUpdated: Timestamp.now(),
      imageUrl: imageUrl,
      // Ensure collaborator arrays are up-to-date
      collaborators: collaborators,
      collaboratorUids: _currentExperience.collaboratorUids,
      collaboratorEmails: _currentExperience.collaboratorEmails,
    );

    await ref.doc(experienceId).update(_currentExperience.toMap());

    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteExperience() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this experience?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection("Experiences")
                  .doc(widget.experienceId)
                  .delete();
              if (mounted) {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // page
              }
            },
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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

  void _toggleSelectSuggestion(Map<String, dynamic> suggestion) {
    final email = (suggestion['email'] as String?) ?? '';
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

    final experienceRef = FirebaseFirestore.instance
        .collection('Experiences')
        .doc(widget.experienceId!);
    final notifRef = FirebaseFirestore.instance.collection('Notifications');

    final doc = await experienceRef.get();
    List<dynamic> existingCollabs = List.from(
      doc.data()?['collaborators'] ?? [],
    );

    final batch = FirebaseFirestore.instance.batch();

    for (var s in selectedSuggestions) {
      final rawEmail = (s['email'] as String?) ?? '';
      final email = rawEmail.toLowerCase().trim();
      final uid = s['uid'] as String?;

      if (currentUser.email?.toLowerCase() == email) continue;

      final alreadyExists = existingCollabs.any(
        (c) => (c['email'] as String?)?.toLowerCase() == email,
      );

      if (alreadyExists) continue;

      final newCollab = {
        'email': email,
        'uid': uid,
        'status': 'pending',
        'invitedBy': currentUser.email?.toLowerCase(),
      };
      existingCollabs.add(newCollab);

      // Create notification
      final notification = AppNotification(
        id: '',
        type: 'invite',
        recipientEmail: email,
        recipientUid: uid,
        experienceId: widget.experienceId!,
        experienceName: _nameController.text.trim(),
        senderEmail: currentUser.email?.toLowerCase(),
        status: 'unread',
        createdAt: Timestamp.now(),
      );

      final notifDoc = notifRef.doc();
      batch.set(notifDoc, notification.toMap());
    }

    // Recompute accepted collaborator IDs & emails
    final Set<String> uids = {};
    final Set<String> emails = {};
    for (var c in existingCollabs) {
      if ((c['status'] as String?) == 'accepted') {
        final uid = c['uid'] as String?;
        final email = (c['email'] as String?)?.toLowerCase();
        if (uid != null) uids.add(uid);
        if (email != null) emails.add(email);
      }
    }

    batch.update(experienceRef, {
      'collaborators': existingCollabs,
      'collaboratorUids': uids.toList(),
      'collaboratorEmails': emails.toList(),
    });

    await batch.commit();

    setState(() {
      collaborators = existingCollabs
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      selectedSuggestions.clear();
      suggestionResults.clear();
      _collabSearchController.clear();
    });
  }

  Future<void> _navigateToContentPage(String device) async {
    dynamic result;

    final initialSelections = booths
        .where((b) => b['device'] == device && b['contentName'] != null)
        .map((b) => b['contentName'] as String)
        .toList();

    Widget page;
    switch (device) {
      case "iCube":
        page = iCubeTestPage(
          selectionMode: true,
          managerId: FirebaseAuth.instance.currentUser?.uid,
          experienceId: widget.experienceId,
          initialSelectedContents: initialSelections,
        );
        break;
      case "iRig":
        page = IrigTestPage(
          selectionMode: true,
          managerId: FirebaseAuth.instance.currentUser?.uid,
          experienceId: widget.experienceId,
          initialSelectedContents: initialSelections,
        );
        break;
      case "iCreate":
        page = iCreateTestPage(
          selectionMode: true,
          managerId: FirebaseAuth.instance.currentUser?.uid,
          experienceId: widget.experienceId,
          initialSelectedContents: initialSelections,
        );
        break;
      case "Storytime":
        page = StoryTimeTestPage(
          selectionMode: true,
          managerId: FirebaseAuth.instance.currentUser?.uid,
          experienceId: widget.experienceId,
          initialSelectedContents: initialSelections,
        );
        break;
      default:
        return;
    }

    result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (result != null) {
      final existingNames = booths
          .where((b) => b['device'] == device && b['contentName'] != null)
          .map((b) => (b['contentName'] as String).toLowerCase())
          .toSet();

      if (result is String && result.trim().isNotEmpty) {
        final name = result.trim();
        if (!existingNames.contains(name.toLowerCase())) {
          _addBooth(device, contentName: name);
        }
      } else if (result is List) {
        for (var item in result) {
          if (item is String) {
            final name = item.trim();
            if (name.isNotEmpty &&
                !existingNames.contains(name.toLowerCase())) {
              _addBooth(device, contentName: name);
            }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Experience Name"),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_imageUrl != null
                                ? NetworkImage(_imageUrl!)
                                : const AssetImage('assets/placeholder.png')
                                      as ImageProvider),
                    ),
                  ),
                  child: _uploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : const Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.camera_alt, color: Colors.white),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => category = value),
              ),
              const SizedBox(height: 24),

              if (editing) ...[
                const Text(
                  "Add Collaborator",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
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
                      if (suggestionResults.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 160),
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
                                    ? const Icon(
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
                            child: const Text('Add To Experience'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
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
                      collaborators.isEmpty
                          ? const Text(
                              'No collaborators yet.',
                              style: TextStyle(color: Colors.grey),
                            )
                          : Column(
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
                const SizedBox(height: 24),
              ],

              const Text(
                "Booths",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: booths.isEmpty
                    ? const Center(
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
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.device_hub,
                                color: Color.fromRGBO(143, 148, 251, 1),
                              ),
                              title: Text(
                                booth["device"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: booth["contentName"] != null
                                  ? Text(
                                      "Content: ${booth["contentName"]}",
                                      style: const TextStyle(fontSize: 12),
                                    )
                                  : const Text(
                                      "No specific content",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Booth",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: devices
                          .map(
                            (device) => ElevatedButton(
                              onPressed: () => _navigateToContentPage(device),
                              child: Text(device),
                            ),
                          )
                          .toList(),
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameController.dispose();
    _collabSearchController.dispose();
    super.dispose();
  }
}
