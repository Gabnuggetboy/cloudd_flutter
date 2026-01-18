import 'dart:async';
import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:cloudd_flutter/models/experience.dart';
import 'package:cloudd_flutter/services/experience_service.dart';
import 'package:provider/provider.dart';
import 'add_content_page.dart';
import 'package:cloudd_flutter/theme_provider.dart';

class ExperienceDetailsPage extends StatefulWidget {
  final String? experienceId;
  const ExperienceDetailsPage({super.key, this.experienceId});

  @override
  State<ExperienceDetailsPage> createState() => _ExperienceDetailsPageState();
}

class _ExperienceDetailsPageState extends State<ExperienceDetailsPage> {
  final _service = ExperienceService();
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
  Map<String, dynamic>? owner; // {uid, email}

  final List<String> devices = ["iCube", "iRig", "iCreate", "Storytime"];
  final List<String> categories = [
    "Education",
    "Entertainment",
    "Technology",
    "Art",
    "Workshop",
  ];

  bool editing = false;
  bool loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    editing = widget.experienceId != null;
    if (editing) {
      _loadExperience();
    } else {
      loading = false;
    }
  }

  Future<void> _loadExperience() async {
    final exp = await _service.getExperience(widget.experienceId!);
    if (exp == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Experience not found")));
        Navigator.pop(context);
      }
      return;
    }

    setState(() {
      _nameController.text = exp.name;
      category = exp.category;
      _imageUrl = exp.imageUrl;
      booths = List<Map<String, dynamic>>.from(exp.booths);
      // Collaborators no longer include creator, so use directly
      collaborators = List<Map<String, dynamic>>.from(exp.collaborators);
      owner = exp.owner;
      loading = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => suggestionResults = []);
      return;
    }

    final results = await _service.searchManagersForInvite(
      query.trim().toLowerCase(),
    );

    if (!mounted) return;

    final selfEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    final filtered = results.where((r) {
      final email = (r['email'] as String?)?.toLowerCase() ?? '';
      // Exclude current user from suggestions
      if (selfEmail != null && email == selfEmail) return false;
      // Exclude already accepted collaborators
      final isAccepted = collaborators.any(
        (c) =>
            (c['email'] as String?)?.toLowerCase() == email &&
            c['status'] == 'accepted',
      );
      return !isAccepted;
    }).toList();

    setState(() => suggestionResults = filtered);
  }

  Future<void> _inviteSelectedCollaborators() async {
    if (widget.experienceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please save experience first")),
      );
      return;
    }

    if (selectedSuggestions.isEmpty) return;

    try {
      await _service.inviteCollaborators(
        experienceId: widget.experienceId!,
        newInvitees: selectedSuggestions,
        experienceName: _nameController.text.trim(),
      );

      // Refresh
      final fresh = await _service.getExperience(widget.experienceId!);
      if (fresh != null && mounted) {
        // Collaborators no longer include creator
        setState(() {
          collaborators = List<Map<String, dynamic>>.from(fresh.collaborators);
          selectedSuggestions.clear();
          suggestionResults.clear();
          _collabSearchController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to invite: $e")));
      }
    }
  }

  Future<void> _saveExperience() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an experience name."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _uploadingImage = true);

    try {
      String experienceId;
      if (editing) {
        experienceId = widget.experienceId!;
      } else {
        experienceId = await _service.createExperience(
          name: name,
          category: category,
          imageUrl: null,
          initialBooths: booths,
        );
      }

      String? newImageUrl;
      if (_selectedImage != null) {
        newImageUrl = await _service.uploadExperienceImage(
          experienceId,
          _selectedImage!,
        );
      }

      await _service.updateExperiencePartial(experienceId, {
        'name': name,
        'category': category,
        'booths': booths,
        'imageUrl': newImageUrl ?? _imageUrl,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _deleteExperience() async {
    if (widget.experienceId == null) return;

    final confirmed = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteExperience(widget.experienceId!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      }
    }
  }

  Future<void> _openAddContentPage() async {
    // Build initial selections per device from current booths
    final Map<String, List<String>> initial = {
      'iCube': [],
      'iRig': [],
      'iCreate': [],
      'Storytime': [],
    };
    for (final b in booths) {
      final device = (b['device'] ?? '').toString();
      final content = b['contentName'] as String?;
      if (content != null && initial.containsKey(device)) {
        initial[device]!.add(content);
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddContentPage(
          selectionMode: true,
          managerId: FirebaseAuth.instance.currentUser?.uid,
          experienceId: widget.experienceId,
          initialSelectedByDevice: initial,
        ),
      ),
    );

    if (result == null) return;

    // Result format: Map<String, List<String>> device -> contents
    if (result is Map<String, List<String>>) {
      setState(() {
        for (final entry in result.entries) {
          final device = entry.key;
          final newContents = entry.value;

          // Remove all booths for this device first
          booths.removeWhere((b) => b['device'] == device);

          // Add back only the selected contents
          for (final name in newContents) {
            final trimmed = name.trim();
            if (trimmed.isNotEmpty) {
              booths.add({"device": device, "contentName": trimmed});
            }
          }
        }
      });
    }
  }

  Map<String, List<String>> _groupBoothsByDevice() {
    final grouped = <String, List<String>>{};
    for (final booth in booths) {
      final device = (booth['device'] ?? '').toString();
      final content = (booth['contentName'] ?? '').toString();
      if (device.isEmpty || content.isEmpty) continue;
      grouped.putIfAbsent(device, () => []);
      if (!grouped[device]!.contains(content)) {
        grouped[device]!.add(content);
      }
    }
    return grouped;
  }

  Widget _buildBoothContentGrid(List<String> contents) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: contents.length,
      itemBuilder: (_, index) {
        final name = contents[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleSelectSuggestion(Map<String, dynamic> suggestion) {
    final email = (suggestion['email'] as String?) ?? '';
    setState(() {
      if (selectedSuggestions.any((s) => s['email'] == email)) {
        selectedSuggestions.removeWhere((s) => s['email'] == email);
      } else {
        selectedSuggestions.add(suggestion);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final boothsByDevice = _groupBoothsByDevice();

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? "Edit Experience" : "New Experience"),
        actions: editing
            ? [
                IconButton(
                  tooltip: 'Delete Experience',
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _deleteExperience,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Experience Name",
                  ),
                ),
                const SizedBox(height: 16),

                // Image
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
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Category
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

                // Collaborators Section (only when editing)
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
                          "Add collaborators to this experience",
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
                            _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 300),
                              () => _searchUsers(value.trim().toLowerCase()),
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
                              itemBuilder: (context, index) {
                                final s = suggestionResults[index];
                                final email = s['email'] ?? '';
                                final selected = selectedSuggestions.any(
                                  (e) => e['email'] == email,
                                );

                                return ListTile(
                                  tileColor: selected
                                      ? Colors.green.shade50
                                      : null,
                                  title: Text(email),
                                  subtitle: const Text(
                                    "Invite as collaborator",
                                  ),
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
                                  : _inviteSelectedCollaborators,
                              child: const Text('Add To Experience'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Owner and Collaborators
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
                        // Owner Section
                        const Text(
                          'Owner',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Builder(
                            builder: (context) {
                              final currentUserEmail =
                                  FirebaseAuth.instance.currentUser?.email
                                      ?.toLowerCase() ??
                                  '';
                              final ownerEmail =
                                  (owner?['email'] as String?)?.toLowerCase() ??
                                  '';
                              final isCurrentUserOwner =
                                  currentUserEmail == ownerEmail &&
                                  ownerEmail.isNotEmpty;
                              return ListTile(
                                leading: const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                ),
                                title: editing && widget.experienceId != null
                                    ? Text(
                                        isCurrentUserOwner ? 'You' : ownerEmail,
                                      )
                                    : const Text('Experience Creator'),
                                subtitle: null,
                              );
                            },
                          ),
                        ),

                        // Collaborators Section
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
                                      subtitle: status == 'pending'
                                          ? const Text('Pending invite')
                                          : null,
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Booths",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openAddContentPage,
                      child: const Text("Add Content"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (boothsByDevice.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(70),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Center(
                      child: Text(
                        "No booths added",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: boothsByDevice.entries.map((entry) {
                        final device = entry.key;
                        final contents = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            title: Text(
                              device,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            children: [_buildBoothContentGrid(contents)],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          final barColor = themeProvider.isDarkMode
              ? Colors.black
              : Colors.grey.shade100;
          return SafeArea(
            top: false,
            child: Container(
              color: barColor,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _uploadingImage ? null : _saveExperience,
                  child: _uploadingImage
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Save"),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _collabSearchController.dispose();
    super.dispose();
  }
}
