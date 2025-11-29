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

// Import demo data service
import '../services/demo_data_service.dart';

// Import chat page
import 'nexus_chat.dart';
import 'nexus_search.dart';

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
  final demoDataService = DemoDataService();

  bool isModelDownloaded = false;
  bool isModelLoaded = false;
  bool isRAGInitialized = false;
  bool isBusy = false;
  String statusMessage = 'Initializing system...';
  DatabaseStats? dbStats;
  List<Document> recentDocuments = [];

  // Processing steps tracking
  final List<ProcessingStep> _processingSteps = [];
  bool _showProcessingSteps = true;

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

  void _addProcessingStep(String step, {String? detail}) {
    setState(() {
      _processingSteps.add(ProcessingStep(
        step: step,
        detail: detail,
        timestamp: DateTime.now(),
      ));
    });
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
    debugPrint('[NexusHome] Getting database statistics...');
    try {
      final stats = await rag.getStats();
      final allDocs = await rag.getAllDocuments();

      // Sort by ID descending (most recent first) and take top 5
      allDocs.sort((a, b) => b.id.compareTo(a.id));

      setState(() {
        dbStats = stats;
        recentDocuments = allDocs.take(5).toList();
      });

      debugPrint('[NexusHome] Database stats updated:');
      debugPrint('[NexusHome]   - Total documents: ${stats.totalDocuments}');
      debugPrint(
          '[NexusHome]   - Recent documents loaded: ${recentDocuments.length}');
    } catch (e, stackTrace) {
      debugPrint('[NexusHome] ERROR getting database stats: $e');
      debugPrint('[NexusHome] Stack trace: $stackTrace');
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
        _processingSteps.clear();
      });

      _addProcessingStep('📂 Opening file picker...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        String extension = result.files.single.extension ?? 'txt';

        _addProcessingStep(
          '✅ File selected: $fileName',
          detail:
              'Size: ${(result.files.single.size / 1024).toStringAsFixed(1)} KB',
        );

        _addProcessingStep('📖 Reading file content...');
        final stopwatch = Stopwatch()..start();
        String text = await _getFileContent(filePath, extension);
        stopwatch.stop();

        if (text.isEmpty) {
          _addProcessingStep('❌ Failed to extract text from file');
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Could not extract text from file')));
          setState(() {
            isBusy = false;
            statusMessage = 'System Ready';
          });
          return;
        }

        _addProcessingStep(
          '✅ Content extracted',
          detail:
              '${text.length} characters in ${stopwatch.elapsedMilliseconds}ms',
        );

        // Calculate estimated chunks
        final chunkSize = 500; // Default chunk size
        final estimatedChunks = (text.length / chunkSize).ceil();

        _addProcessingStep(
          '🔪 Chunking document...',
          detail:
              'Creating ~$estimatedChunks chunks (${chunkSize}chars each, 50char overlap)',
        );

        _addProcessingStep(
          '🧮 Generating embeddings...',
          detail: 'Using qwen3-0.6-embed model (1024 dimensions)',
        );

        final embeddingStopwatch = Stopwatch()..start();
        final document = await rag.storeDocument(
          fileName: fileName,
          filePath: filePath,
          content: text,
          fileSize: result.files.single.size,
        );
        embeddingStopwatch.stop();

        _addProcessingStep(
          '✅ Embeddings generated',
          detail: '~$estimatedChunks embeddings created',
        );

        _addProcessingStep(
          '💾 Stored in vector database',
          detail:
              'Document ID: ${document.id} • Total: ${(embeddingStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
        );

        debugPrint('Stored doc: ${document.id}');

        _addProcessingStep('📊 Updating database statistics...');
        await getDBStats();
        _addProcessingStep('✅ Complete!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added $fileName')),
          );
        }
      } else {
        _addProcessingStep('ℹ️ File selection cancelled');
      }
    } catch (e) {
      debugPrint('Error adding doc: $e');
      _addProcessingStep('❌ Error: $e');
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

  Future<bool> _checkIfDemoDataExists() async {
    debugPrint('[NexusHome] Checking if demo data already exists...');
    try {
      final allDocs = await rag.getAllDocuments();
      // Check if any documents have the demo_data prefix in their file path
      final demoDataCount =
          allDocs.where((doc) => doc.filePath.startsWith('demo_data/')).length;
      debugPrint(
          '[NexusHome] Found $demoDataCount demo data documents in database');
      return demoDataCount > 0;
    } catch (e) {
      debugPrint('[NexusHome] Error checking for demo data: $e');
      return false;
    }
  }

  Future<void> loadDemoData({bool forceReload = false}) async {
    debugPrint('[NexusHome] loadDemoData() called (forceReload: $forceReload)');

    if (!isRAGInitialized) {
      debugPrint(
          '[NexusHome] ERROR: RAG not initialized, cannot load demo data');
      return;
    }

    debugPrint('[NexusHome] RAG initialized, proceeding with demo data load');

    try {
      setState(() {
        isBusy = true;
        statusMessage = 'Checking existing data...';
        _processingSteps.clear();
      });

      _addProcessingStep('🔍 Checking for existing demo data...');

      // Check if demo data already exists
      if (!forceReload) {
        final exists = await _checkIfDemoDataExists();
        if (exists) {
          debugPrint('[NexusHome] Demo data already exists, skipping load');
          _addProcessingStep('ℹ️ Demo data already loaded');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Demo data already loaded! No need to reload.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          setState(() {
            isBusy = false;
            statusMessage = 'System Ready';
          });
          return;
        }
        _addProcessingStep('✅ No existing demo data found');
      } else {
        debugPrint(
            '[NexusHome] Force reload requested, clearing existing demo data...');
        _addProcessingStep('🗑️ Clearing existing demo data...');
        // Clear existing demo data
        final allDocs = await rag.getAllDocuments();
        final demoDocs =
            allDocs.where((doc) => doc.filePath.startsWith('demo_data/'));
        int cleared = 0;
        for (final doc in demoDocs) {
          await rag.deleteDocument(doc.id);
          cleared++;
          debugPrint(
              '[NexusHome] Deleted existing demo document: ${doc.fileName}');
        }
        _addProcessingStep(
          '✅ Cleared $cleared existing documents',
        );
      }

      setState(() {
        statusMessage = 'Loading demo data...';
      });

      _addProcessingStep('🌐 Fetching LinkedIn posts from API...');
      debugPrint('[NexusHome] Fetching demo data from API...');
      final stopwatch = Stopwatch()..start();
      final posts = await demoDataService.fetchDemoData();
      stopwatch.stop();
      debugPrint(
          '[NexusHome] Fetched ${posts.length} posts in ${stopwatch.elapsedMilliseconds}ms');

      _addProcessingStep(
        '✅ Fetched ${posts.length} LinkedIn posts',
        detail:
            'Retrieved in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
      );

      int successCount = 0;
      int failureCount = 0;

      debugPrint(
          '[NexusHome] Starting to store ${posts.length} posts in RAG database...');
      _addProcessingStep('💾 Processing posts for embedding...');
      final storeStopwatch = Stopwatch()..start();

      // Calculate total estimated chunks for all posts
      final chunkSize = 500;
      int totalEstimatedChunks = 0;
      for (final post in posts) {
        final content = post.toSearchableContent();
        totalEstimatedChunks += (content.length / chunkSize).ceil();
      }

      _addProcessingStep(
        '  ℹ️ Estimated ~$totalEstimatedChunks total chunks',
        detail: 'Across ${posts.length} posts • ${chunkSize}chars per chunk',
      );

      for (int i = 0; i < posts.length; i++) {
        final post = posts[i];
        try {
          debugPrint(
              '[NexusHome] Processing post ${i + 1}/${posts.length}: ${post.displayName}');
          final content = post.toSearchableContent();
          final estimatedChunks = (content.length / chunkSize).ceil();
          debugPrint(
              '[NexusHome]   - Content length: ${content.length} characters (~$estimatedChunks chunks)');

          final doc = await rag.storeDocument(
            fileName: post.displayName,
            filePath: 'demo_data/${post.url}',
            content: content,
            fileSize: content.length,
          );

          debugPrint(
              '[NexusHome]   - Successfully stored document ID: ${doc.id}');
          successCount++;

          // Show each post with chunk count
          _addProcessingStep(
            '  📄 ${i + 1}/${posts.length}: ${post.displayName}',
            detail: '~$estimatedChunks chunks embedded • Doc ID: ${doc.id}',
          );
        } catch (e, stackTrace) {
          debugPrint(
              '[NexusHome] ERROR storing post ${i + 1} (${post.url}): $e');
          debugPrint('[NexusHome] Stack trace: $stackTrace');
          failureCount++;
        }
      }

      storeStopwatch.stop();
      debugPrint(
          '[NexusHome] Storage complete: $successCount successful, $failureCount failed');
      debugPrint(
          '[NexusHome] Total storage time: ${storeStopwatch.elapsedMilliseconds}ms');

      _addProcessingStep(
        '✅ All embeddings generated',
        detail: '~$totalEstimatedChunks embeddings created (1024 dims each)',
      );

      _addProcessingStep(
        '📊 Statistics',
        detail:
            '$successCount successful, $failureCount failed • ${(storeStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s total',
      );

      debugPrint('[NexusHome] Updating database statistics...');
      _addProcessingStep('📊 Updating database statistics...');
      await getDBStats();
      debugPrint(
          '[NexusHome] Database stats updated: ${dbStats?.totalDocuments} total documents');

      _addProcessingStep(
        '✅ Complete!',
        detail: 'Total documents: ${dbStats?.totalDocuments}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(forceReload
                ? 'Reloaded $successCount LinkedIn posts'
                : 'Loaded $successCount LinkedIn posts into knowledge base'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      debugPrint('[NexusHome] Demo data loading completed successfully');
      debugPrint(
          '[NexusHome] Demo data is now persisted locally and will survive app restarts');
    } catch (e, stackTrace) {
      debugPrint('[NexusHome] ERROR loading demo data: $e');
      debugPrint('[NexusHome] Stack trace: $stackTrace');
      _addProcessingStep('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading demo data: $e')),
        );
      }
    } finally {
      setState(() {
        isBusy = false;
        statusMessage = 'System Ready';
      });
      debugPrint('[NexusHome] loadDemoData() finished, isBusy set to false');
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
        onLoadDemoDataTap: () {
          Navigator.pop(ctx);
          loadDemoData(forceReload: false);
        },
        onReloadDemoDataTap: () {
          Navigator.pop(ctx);
          loadDemoData(forceReload: true);
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
                  if (!isRAGInitialized || !isModelLoaded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please wait for system to initialize'),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NexusChatPage(
                        lm: lm,
                        rag: rag,
                      ),
                    ),
                  );
                },
                onSearchTap: () {
                  if (!isRAGInitialized) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please wait for system to initialize'),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NexusSearchPage(rag: rag),
                    ),
                  );
                },
                onManageTap: _showManageKnowledgeSheet,
              ),
              const SizedBox(height: 30),
              if (_processingSteps.isNotEmpty) ...[
                _buildProcessingSteps(),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: NexusRecentActivity(
                  dbStats: dbStats,
                  recentDocuments: recentDocuments,
                  cardDark: _cardDark,
                  accentPurple: _accentPurple,
                  accentGreen: _accentGreen,
                  onViewAllTap: () {
                    // TODO: Navigate to full documents list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Full documents view coming soon!'),
                      ),
                    );
                  },
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

  Widget _buildProcessingSteps() {
    return Container(
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _accentGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _showProcessingSteps = !_showProcessingSteps;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    _showProcessingSteps
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: _accentGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processing Steps',
                    style: TextStyle(
                      color: _accentGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isBusy)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_accentGreen),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_showProcessingSteps) ...[
            const Divider(
              color: Color(0xFF2A2A2A),
              height: 1,
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _processingSteps.map((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.step,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          if (step.detail != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              step.detail!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProcessingStep {
  final String step;
  final String? detail;
  final DateTime timestamp;

  ProcessingStep({
    required this.step,
    this.detail,
    required this.timestamp,
  });
}
