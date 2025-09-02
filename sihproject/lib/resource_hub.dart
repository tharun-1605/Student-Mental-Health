import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourceHubPage extends StatefulWidget {
  const ResourceHubPage({super.key});

  @override
  State<ResourceHubPage> createState() => _ResourceHubPageState();
}

class _ResourceHubPageState extends State<ResourceHubPage> {
  String _selectedLanguage = 'All';
  String _selectedCategory = 'All';
  final List<String> _languages = ['All', 'English', 'Hindi', 'Tamil', 'Telugu', 'Bengali'];
  final List<String> _categories = ['All', 'Videos', 'Audios', 'Articles'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource Hub'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedLanguage,
                    decoration: const InputDecoration(labelText: 'Language'),
                    items: _languages.map((lang) {
                      return DropdownMenuItem(value: lang, child: Text(lang));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('resources').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading resources'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final resources = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final language = data['language'] ?? 'English';
                  final category = data['category'] ?? 'Articles';

                  bool languageMatch = _selectedLanguage == 'All' || language == _selectedLanguage;
                  bool categoryMatch = _selectedCategory == 'All' || category == _selectedCategory;

                  return languageMatch && categoryMatch;
                }).toList();

                if (resources.isEmpty) {
                  return const Center(child: Text('No resources found'));
                }

                return ListView.builder(
                  itemCount: resources.length,
                  itemBuilder: (context, index) {
                    final doc = resources[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? 'Untitled';
                    final description = data['description'] ?? '';
                    final url = data['url'] ?? '';
                    final category = data['category'] ?? 'Articles';
                    final language = data['language'] ?? 'English';
                    final duration = data['duration'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          category == 'Videos' ? Icons.video_library :
                          category == 'Audios' ? Icons.audiotrack : Icons.article,
                        ),
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(description),
                            const SizedBox(height: 4),
                            Text('Language: $language | Duration: $duration'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () async {
                            if (url.isNotEmpty) {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
