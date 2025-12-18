import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class IrigTestPage extends StatefulWidget {
  const IrigTestPage({super.key});

  @override
  State<IrigTestPage> createState() => _IrigTestPageState();
}

class _IrigTestPageState extends State<IrigTestPage> {
  final String apiBaseUrl = 'http://192.168.0.126:5000';
  List<dynamic> contents = [];
  bool isLoading = true;
  String? errorMessage;
  String? runningContent;

  final Duration requestTimeout = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    fetchContents();
  }

  Future<void> fetchContents() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/contents'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        setState(() {
          contents = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load contents: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage =
            'Cannot connect to server.\n\n'
            'Troubleshooting:\n'
            '1. Ensure Flask API is running on 192.168.0.126:5000\n'
            '2. Check both devices are on the same network\n'
            '3. Verify Flask is running with host="0.0.0.0"\n'
            '4. Check firewall settings on the API PC\n\n'
            'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> launchContent(String contentName) async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/launch/$contentName'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          runningContent = contentName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launching ${data['content']}: ${data['status']}'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch content'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> stopContent(String contentName) async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl/close/$contentName'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            runningContent = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stopped ${data['closed_exe']}'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Build executable not found'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop content'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iRig Test'),
        backgroundColor: const Color.fromRGBO(143, 148, 251, 1),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.left,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: fetchContents,
                          icon: Icon(Icons.refresh),
                          label: Text('Retry Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(143, 148, 251, 1),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
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
                      final isRunning = runningContent == content['name'];
                      return GestureDetector(
                        onTap: isRunning
                            ? null
                            : () => launchContent(content['name']),
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
                                    children: [
                                      Image.network(
                                        '$apiBaseUrl${content['icon_url']}',
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
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value:
                                                  loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                      if (isRunning)
                                        Container(
                                          color: Colors.black.withOpacity(0.5),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.play_circle_fill,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Running',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      content['name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (isRunning)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: () =>
                                              stopContent(content['name']),
                                          icon: Icon(
                                            Icons.stop_circle,
                                            size: 18,
                                          ),
                                          label: Text('Stop'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          if (runningContent != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                color: Color.fromRGBO(143, 148, 251, 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle_filled, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$runningContent is running',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => stopContent(runningContent!),
                        icon: Icon(Icons.stop, size: 18),
                        label: Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
