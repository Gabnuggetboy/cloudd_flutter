import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/services/device_loading_service.dart';
import 'package:cloudd_flutter/models/manager_content_selection.dart';

//THIS PAGE IS NOT IN USE, REPLACED BY add_content_page.dart
class StoryTimeTestPage extends StatefulWidget {
  final bool selectionMode;
  final String? managerId;
  final String? experienceId;
  final List<String>? initialSelectedContents;

  const StoryTimeTestPage({
    super.key,
    this.selectionMode = true,
    this.managerId,
    this.experienceId,
    this.initialSelectedContents,
  });

  @override
  State<StoryTimeTestPage> createState() => _StoryTimeTestPageState();
}

class _StoryTimeTestPageState extends State<StoryTimeTestPage> {
  List<dynamic> contents = [];
  bool isLoading = true;
  String? errorMessage;

  Set<String> selectedContents = {};

  @override
  void initState() {
    super.initState();

    // Pre-select contents if provided
    if (widget.initialSelectedContents != null &&
        widget.initialSelectedContents!.isNotEmpty) {
      selectedContents = Set<String>.from(widget.initialSelectedContents!);
    } else if (widget.managerId != null && widget.experienceId != null) {
      _loadSelectedContents();
    }

    fetchContents();
  }

  Future<void> _loadSelectedContents() async {
    if (widget.managerId == null || widget.experienceId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .collection('ManagerContentSelections')
          .doc('storytime_${widget.managerId}')
          .get();

      if (doc.exists) {
        final selection = ManagerContentSelection.fromDoc(doc);
        setState(() {
          selectedContents = Set<String>.from(selection.selectedContents);
        });
      }
    } catch (_) {
      // Silent ignore
    }
  }

  Future<void> _saveSelectedContents() async {
    if (widget.managerId == null || widget.experienceId == null) return;

    try {
      // Ensure parent document exists (helps visibility in Firestore console)
      await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .set({}, SetOptions(merge: true));

      final selection = ManagerContentSelection(
        id: 'storytime_${widget.managerId}',
        managerId: widget.managerId!,
        device: 'Storytime',
        experienceId: widget.experienceId!,
        selectedContents: selectedContents.toList(),
      );

      await FirebaseFirestore.instance
          .collection('Experiences')
          .doc(widget.experienceId)
          .collection('ManagerContentSelections')
          .doc(selection.id)
          .set(selection.toMap());
    } catch (_) {
      // Silent ignore
    }
  }

  Future<void> fetchContents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await DeviceLoadingService.fetchStorytimeContents();

      if (result.error != null) {
        setState(() {
          errorMessage = result.error;
          isLoading = false;
        });
      } else {
        setState(() {
          contents = result.contents;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Please connect to Digital_Dream_2_5G wifi.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Storytime Content',
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color.fromRGBO(143, 148, 251, 1),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () async {
              await _saveSelectedContents();
              if (mounted) {
                Navigator.pop(context, selectedContents.toList());
              }
            },
            child: const Text(
              'Done',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Logo at the top
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Image.network(
              'https://firebasestorage.googleapis.com/v0/b/ddapp-c89cb.firebasestorage.app/o/digitaldream_logos%2Fstorytime_logo.png?alt=media&token=044b121e-a765-487d-b4ee-8599e8aea0d0',
              height: 80,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: fetchContents,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(
                                143,
                                148,
                                251,
                                1,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : contents.isEmpty
                ? const Center(child: Text('No contents available'))
                : RefreshIndicator(
                    onRefresh: fetchContents,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                      itemCount: contents.length,
                      itemBuilder: (context, index) {
                        final content = contents[index];
                        final contentName = content['name'];
                        final isSelected = selectedContents.contains(
                          contentName,
                        );

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedContents.remove(contentName);
                              } else {
                                selectedContents.add(contentName);
                              }
                            });
                          },
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          DeviceLoadingService.getContentIconUrl(
                                            'Storytime',
                                            content['icon_url'] ?? '',
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    size: 64,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                          loadingBuilder:
                                              (context, child, progress) {
                                                if (progress == null) {
                                                  return child;
                                                }
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              },
                                        ),
                                        if (isSelected)
                                          Container(
                                            color: Colors.black.withOpacity(
                                              0.5,
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 48,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    content['name'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
