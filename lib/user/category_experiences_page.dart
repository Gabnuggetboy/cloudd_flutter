import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'explore_experience_page.dart';
import 'package:cloudd_flutter/models/experience.dart';

class CategoryExperiencesPage extends StatelessWidget {
  final String category;

  const CategoryExperiencesPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Experiences')
            .where('category', isEqualTo: category)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final experiences = snapshot.data!.docs
              .map((doc) => Experience.fromDoc(doc))
              .toList();

          if (experiences.isEmpty) {
            return const Center(child: Text('No experiences in this category'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: experiences.length,
            itemBuilder: (context, index) {
              final experience = experiences[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    experience.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExploreExperiencePage(
                          experienceId: experience.id,
                          experienceName: experience.name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
