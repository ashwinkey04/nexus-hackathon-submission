import 'package:cactus/cactus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

class NexusHomePage extends StatefulWidget {
  const NexusHomePage({super.key});

  @override
  State<NexusHomePage> createState() => _NexusHomePageState();
}

class _NexusHomePageState extends State<NexusHomePage> {
  int _selectedIndex = 0;

  // Brand colors
  final Color _bgDark = const Color(0xFF050505);
  final Color _cardDark = const Color(0xFF1A1A1A);
  final Color _accentGreen = const Color(0xFF8CFF9E);
  final Color _accentPaleGreen = const Color(0xFFCCFFD6);
  final Color _accentPurple = const Color(0xFFE0C8FF);

  // Cactus RAG State
  final lm = CactusLM();
  final rag = CactusRAG();

  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isRAGInitialized = false;
  bool isBusy = false;
  String statusMessage = 'Initializing system...';
  DatabaseStats? dbStats;

  @override
  void initState() {
    super.initState();
    // Auto-start initialization sequence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startInitializationSequence();
    });
  }

  @override
  void dispose() {
    lm.unload();
    rag.close();
    super.dispose();
  }

  Future<void> _startInitializationSequence() async {
    await downloadModel();
    await initializeModel();
    await initializeRAG();
    setState(() {
      statusMessage = 'System Ready';
    });
  }

  Future<void> downloadModel() async {
    setState(() {
      isBusy = true;
      statusMessage = 'Downloading model...';
    });
    try {
      // Check if already downloaded (optimization) - skipping for simple demo logic
      await lm.downloadModel(
        model: 'qwen3-0.6-embed',
        downloadProcessCallback: (progress, status, isError) {
          if (mounted) {
            setState(() {
              statusMessage = isError
                  ? 'Error: $status'
                  : '$status ${(progress != null ? '(${((progress) * 100).toInt()}%)' : '')}';
            });
          }
        },
      );
      setState(() {
        isModelDownloaded = true;
      });
    } catch (e) {
      debugPrint('Error downloading: $e');
    }
  }

  Future<void> initializeModel() async {
    if (!isModelDownloaded) return;
    setState(() {
      statusMessage = 'Loading model...';
    });
    try {
      await lm.initializeModel(
          params: CactusInitParams(model: 'qwen3-0.6-embed'));
      setState(() {
        isModelLoaded = true;
      });
    } catch (e) {
      debugPrint('Error initializing model: $e');
    }
  }

  Future<void> initializeRAG() async {
    if (!isModelLoaded) return;
    setState(() {
      statusMessage = 'Preparing knowledge base...';
    });
    try {
      await rag.initialize();
      rag.setEmbeddingGenerator((text) async {
        final result = await lm.generateEmbedding(text: text);
        return result.embeddings;
      });
      // Updated chunking settings as per previous conversation
      rag.setChunking(chunkSize: 500, chunkOverlap: 50);

      setState(() {
        isRAGInitialized = true;
      });
      await getDBStats();
    } catch (e) {
      debugPrint('Error init RAG: $e');
    } finally {
      setState(() {
        isBusy = false;
      });
    }
  }

  Future<void> getDBStats() async {
    try {
      final stats = await rag.getStats();
      setState(() {
        dbStats = stats;
      });
    } catch (e) {
      debugPrint('Stats error: $e');
    }
  }

  Future<String> _getPDFtext(String path) async {
    String text = "";
    try {
      text = await ReadPdfText.getPDFtext(path);
    } on PlatformException {
      debugPrint('Failed to get PDF text.');
    }
    return text;
  }

  Future<void> addDocument() async {
    if (!isRAGInitialized) return;

    try {
      setState(() {
        isBusy = true;
        statusMessage = 'Adding document...';
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'], // Expand this later for other types
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;

        // For now, only PDF logic is implemented
        String text = await _getPDFtext(filePath);

        final document = await rag.storeDocument(
          fileName: fileName,
          filePath: filePath,
          content: text,
          fileSize: result.files.single.size,
        );

        debugPrint('Stored doc: ${document.id}');
        await getDBStats();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added $fileName')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding doc: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() {
        isBusy = false;
        statusMessage = 'System Ready';
      });
    }
  }

  Future<void> clearKnowledgeBase() async {
    if (!isRAGInitialized) return;
    setState(() {
      isBusy = true;
      statusMessage = 'Clearing database...';
    });
    try {
      final allDocs = await rag.getAllDocuments();
      for (final doc in allDocs) {
        await rag.deleteDocument(doc.id);
      }
      await getDBStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Knowledge base cleared')),
        );
      }
    } catch (e) {
      debugPrint("Error clearing: $e");
    } finally {
      setState(() {
        isBusy = false;
        statusMessage = 'System Ready';
      });
    }
  }

  void _showManageKnowledgeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage Knowledge',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _accentGreen.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: Icon(Icons.add, color: _accentGreen),
              ),
              title: const Text('Add Document',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Upload PDF to knowledge base',
                  style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                addDocument();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Colors.red),
              ),
              title: const Text('Clear All Data',
                  style: TextStyle(color: Colors.white)),
              subtitle: const Text('Remove all documents',
                  style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                clearKnowledgeBase();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: _cardDark,
                    child: const Icon(Icons.menu, color: Colors.white),
                  ),
                  // Status Indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isBusy
                              ? Colors.amber
                              : _accentGreen.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isBusy ? Colors.amber : _accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusMessage,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    backgroundColor: Colors.grey,
                    backgroundImage: NetworkImage(
                        'https://i.pravatar.cc/150?img=11'), // Placeholder
                    radius: 24,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Greeting
              const Text(
                'Hello, User',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'How can I assist you right now?',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),

              // Action Grid
              Row(
                children: [
                  // Big Left Card (Chat - Promoted)
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to chat page (Placeholder for now)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Chat feature coming soon!')),
                        );
                      },
                      child: Container(
                        height: 180,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _accentGreen,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline,
                                  color: Colors.black, size: 24),
                            ),
                            const Text(
                              'Chat\nwith\nNexus',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right Column
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        // Top Right Card (Search)
                        GestureDetector(
                          onTap: () {
                            // Navigate to search (Placeholder)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Search feature coming soon!')),
                            );
                          },
                          child: Container(
                            height: 82,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _accentPaleGreen,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.search, color: Colors.black),
                                Flexible(
                                  child: Text(
                                    'Search\nDocs',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Bottom Right Card (Manage Knowledge)
                        GestureDetector(
                          onTap: _showManageKnowledgeSheet,
                          child: Container(
                            height: 82,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _accentPurple,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.edit_note, color: Colors.black),
                                Flexible(
                                  child: Text(
                                    'Manage\nKnowledge',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Recent Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Knowledge Base (${dbStats?.totalDocuments ?? 0} docs)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'View All',
                      style: TextStyle(color: _accentGreen),
                    ),
                  ),
                ],
              ),

              // Recent List
              Expanded(
                child: ListView(
                  children: [
                    if (dbStats != null && dbStats!.totalDocuments > 0)
                      _buildRecentItem(
                        icon: Icons.description_outlined,
                        color: _accentPurple,
                        title: 'Recent Document',
                        subtitle: 'Tap "Manage Knowledge" to see all',
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: Text(
                          'No documents yet. Add some!',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 30),
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_accentGreen, Colors.tealAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accentGreen.withOpacity(0.4),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: addDocument,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: isBusy
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: Colors.black))
              : const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ),

      // Bottom Nav Bar
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BottomAppBar(
          color: _cardDark,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(Icons.home_filled,
                      color: _selectedIndex == 0 ? _accentGreen : Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 0),
                ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 1),
                ),
                const SizedBox(width: 40), // Space for FAB
                IconButton(
                  icon:
                      const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 2),
                ),
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Colors.grey),
                  onPressed: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.more_horiz, color: Colors.grey.shade600),
        ],
      ),
    );
  }
}
