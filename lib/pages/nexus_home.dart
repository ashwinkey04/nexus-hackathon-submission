import 'package:cactus/cactus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'dart:io';

// Import the new widget components
import '../widgets/nexus/nexus_top_bar.dart';
import '../widgets/nexus/nexus_greeting.dart';
import '../widgets/nexus/nexus_action_grid.dart';
import '../widgets/nexus/nexus_recent_activity.dart';
import '../widgets/nexus/nexus_nav_bar.dart';
import '../widgets/nexus/manage_knowledge_sheet.dart';
import '../widgets/nexus/paste_text_dialog.dart';

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

  // --- RAG LOGIC STARTS HERE ---

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

  Future<String> _getFileContent(String path, String extension) async {
    try {
      if (extension == 'pdf') {
        return await ReadPdfText.getPDFtext(path);
      } else {
        final file = File(path);
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('Failed to get file text: $e');
      return "";
    }
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
        allowedExtensions: ['pdf', 'txt', 'md'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        String extension = result.files.single.extension ?? 'txt';

        String text = await _getFileContent(filePath, extension);

        if (text.isEmpty) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Could not extract text from file')));
          setState(() {
            isBusy = false;
            statusMessage = 'System Ready';
          });
          return;
        }

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

  Future<void> _savePastedContent(String title, String content) async {
    if (!isRAGInitialized) return;

    try {
      setState(() {
        isBusy = true;
        statusMessage = 'Saving text...';
      });

      final fileName = '$title.txt';

      final document = await rag.storeDocument(
        fileName: fileName,
        filePath: 'manual_entry/$fileName',
        content: content,
        fileSize: content.length,
      );

      debugPrint('Stored manual doc: ${document.id}');
      await getDBStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$title" to knowledge base')),
        );
      }
    } catch (e) {
      debugPrint('Error saving text: $e');
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

  // --- UI HELPERS ---

  void _showPasteTextDialog() {
    showDialog(
      context: context,
      builder: (ctx) => PasteTextDialog(
        cardDark: _cardDark,
        accentGreen: _accentGreen,
        onSave: _savePastedContent,
      ),
    );
  }

  void _showManageKnowledgeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent, // Transparent to let sheet handle styling
      isScrollControlled: true,
      builder: (ctx) => ManageKnowledgeSheet(
        cardDark: _cardDark,
        accentGreen: _accentGreen,
        accentPurple: _accentPurple,
        onUploadTap: () {
          Navigator.pop(ctx);
          addDocument();
        },
        onPasteTap: () {
          Navigator.pop(ctx);
          _showPasteTextDialog();
        },
        onClearTap: () {
          Navigator.pop(ctx);
          clearKnowledgeBase();
        },
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
              NexusTopBar(
                isBusy: isBusy,
                statusMessage: statusMessage,
                cardDark: _cardDark,
                accentGreen: _accentGreen,
              ),
              const SizedBox(height: 30),
              const NexusGreeting(),
              const SizedBox(height: 30),
              NexusActionGrid(
                accentGreen: _accentGreen,
                accentPaleGreen: _accentPaleGreen,
                accentPurple: _accentPurple,
                onChatTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat feature coming soon!')),
                  );
                },
                onSearchTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Search feature coming soon!')),
                  );
                },
                onManageTap: _showManageKnowledgeSheet,
              ),
              const SizedBox(height: 30),
              Expanded(
                child: NexusRecentActivity(
                  dbStats: dbStats,
                  cardDark: _cardDark,
                  accentPurple: _accentPurple,
                  accentGreen: _accentGreen,
                  onViewAllTap: () {},
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
        child: NexusNavBar(
          selectedIndex: _selectedIndex,
          onIndexChanged: (index) => setState(() => _selectedIndex = index),
          onFabTap: () {}, // FAB is handled above
          isBusy: isBusy,
          cardDark: _cardDark,
          accentGreen: _accentGreen,
        ),
      ),
    );
  }
}
