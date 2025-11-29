import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class NexusChatPage extends StatefulWidget {
  final CactusLM lm;
  final CactusRAG rag;

  const NexusChatPage({
    super.key,
    required this.lm,
    required this.rag,
  });

  @override
  State<NexusChatPage> createState() => _NexusChatPageState();
}

class _NexusChatPageState extends State<NexusChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];

  bool isGenerating = false;
  bool isChatModelLoaded = false;
  bool isLoadingChatModel = false;
  String chatModel = 'qwen3-0.6';
  String? currentLoadedModel;

  @override
  void initState() {
    super.initState();
    _initializeChatModel();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChatModel() async {
    debugPrint('[NexusChat] _initializeChatModel() called');
    debugPrint('[NexusChat] Target chat model: $chatModel');

    setState(() {
      isLoadingChatModel = true;
    });

    try {
      debugPrint('[NexusChat] Unloading any existing model...');
      widget.lm.unload();

      debugPrint('[NexusChat] Initializing chat model: $chatModel');
      final stopwatch = Stopwatch()..start();
      await widget.lm.initializeModel(
        params: CactusInitParams(model: chatModel),
      );
      stopwatch.stop();
      debugPrint(
          '[NexusChat] Chat model initialized in ${stopwatch.elapsedMilliseconds}ms');

      setState(() {
        isChatModelLoaded = true;
        currentLoadedModel = chatModel;
      });

      debugPrint('[NexusChat] Chat model ready: $chatModel');
    } catch (e, stackTrace) {
      debugPrint('[NexusChat] ERROR initializing chat model: $e');
      debugPrint('[NexusChat] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chat model: $e')),
        );
      }
    } finally {
      setState(() {
        isLoadingChatModel = false;
      });
      debugPrint('[NexusChat] _initializeChatModel() finished');
    }
  }

  Future<List<double>> _generateEmbedding(String text) async {
    debugPrint('[NexusChat] _generateEmbedding() called');
    debugPrint('[NexusChat]   - Text length: ${text.length} characters');
    debugPrint('[NexusChat]   - Current model: $currentLoadedModel');

    // Temporarily switch to embedding model
    if (currentLoadedModel != 'qwen3-0.6-embed') {
      debugPrint(
          '[NexusChat] Switching to embedding model (qwen3-0.6-embed)...');
      final switchStopwatch = Stopwatch()..start();
      widget.lm.unload();
      await widget.lm.initializeModel(
        params: CactusInitParams(model: 'qwen3-0.6-embed'),
      );
      switchStopwatch.stop();
      currentLoadedModel = 'qwen3-0.6-embed';
      debugPrint(
          '[NexusChat] Switched to embedding model in ${switchStopwatch.elapsedMilliseconds}ms');
    }

    debugPrint('[NexusChat] Generating embedding...');
    final embedStopwatch = Stopwatch()..start();
    final result = await widget.lm.generateEmbedding(text: text);
    embedStopwatch.stop();
    debugPrint(
        '[NexusChat] Embedding generated in ${embedStopwatch.elapsedMilliseconds}ms');
    debugPrint(
        '[NexusChat]   - Embedding dimension: ${result.embeddings.length}');

    // Switch back to chat model
    if (currentLoadedModel != chatModel) {
      debugPrint('[NexusChat] Switching back to chat model ($chatModel)...');
      final switchBackStopwatch = Stopwatch()..start();
      widget.lm.unload();
      await widget.lm.initializeModel(
        params: CactusInitParams(model: chatModel),
      );
      switchBackStopwatch.stop();
      currentLoadedModel = chatModel;
      debugPrint(
          '[NexusChat] Switched back to chat model in ${switchBackStopwatch.elapsedMilliseconds}ms');
    }

    debugPrint('[NexusChat] _generateEmbedding() completed');
    return result.embeddings;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || isGenerating) {
      debugPrint(
          '[NexusChat] _sendMessage() skipped: empty message or already generating');
      return;
    }

    final userMessage = _messageController.text.trim();
    debugPrint('[NexusChat] ========================================');
    debugPrint('[NexusChat] _sendMessage() called');
    debugPrint('[NexusChat] User message: "$userMessage"');
    debugPrint('[NexusChat] Message length: ${userMessage.length} characters');

    _messageController.clear();

    setState(() {
      _messages.add(ChatMessageModel(
        content: userMessage,
        role: 'user',
        timestamp: DateTime.now(),
      ));
      isGenerating = true;
    });

    _scrollToBottom();

    try {
      // Step 1: Search RAG for relevant context
      debugPrint('[NexusChat] Step 1: Searching RAG for relevant context...');
      widget.rag.setEmbeddingGenerator((text) => _generateEmbedding(text));

      final searchStopwatch = Stopwatch()..start();
      final searchResults = await widget.rag.search(
        text: userMessage,
        limit: 3,
      );
      searchStopwatch.stop();

      debugPrint(
          '[NexusChat] RAG search completed in ${searchStopwatch.elapsedMilliseconds}ms');
      debugPrint('[NexusChat] Found ${searchResults.length} relevant chunks');

      // Step 2: Build context from search results
      String context = '';
      List<String> sources = [];

      if (searchResults.isNotEmpty) {
        debugPrint(
            '[NexusChat] Step 2: Building context from search results...');
        context = 'Here is relevant information from the knowledge base:\n\n';
        for (int i = 0; i < searchResults.length; i++) {
          final result = searchResults[i];
          final docName = result.chunk.document.target?.fileName ?? 'Unknown';
          final similarity = (result.distance * 100).toStringAsFixed(1);
          debugPrint(
              '[NexusChat]   - Chunk ${i + 1}: $docName (similarity: $similarity%)');
          debugPrint(
              '[NexusChat]     Content preview: ${result.chunk.content.substring(0, result.chunk.content.length > 100 ? 100 : result.chunk.content.length)}...');
          context += '--- Source ${i + 1}: $docName ---\n';
          context += '${result.chunk.content}\n\n';
          sources.add(docName);
        }
        debugPrint('[NexusChat] Context built: ${context.length} characters');
      } else {
        debugPrint(
            '[NexusChat] No relevant chunks found, proceeding without context');
      }

      // Step 3: Build messages for LLM
      debugPrint('[NexusChat] Step 3: Building messages for LLM...');
      final messages = [
        ChatMessage(
          content:
              'You are Nexus, a helpful AI assistant with access to a knowledge base. '
              'Use the provided context to answer questions accurately. '
              'If the context doesn\'t contain relevant information, say so politely and provide a general response.',
          role: 'system',
        ),
        if (context.isNotEmpty) ChatMessage(content: context, role: 'system'),
        ..._messages
            .where((m) => m.role == 'user' || m.role == 'assistant')
            .map((m) => ChatMessage(content: m.content, role: m.role)),
      ];

      debugPrint('[NexusChat] Total messages: ${messages.length}');
      debugPrint(
          '[NexusChat]   - System messages: ${messages.where((m) => m.role == 'system').length}');
      debugPrint(
          '[NexusChat]   - User messages: ${messages.where((m) => m.role == 'user').length}');
      debugPrint(
          '[NexusChat]   - Assistant messages: ${messages.where((m) => m.role == 'assistant').length}');

      // Step 4: Generate response
      debugPrint('[NexusChat] Step 4: Generating LLM response...');
      final generateStopwatch = Stopwatch()..start();
      final response = await widget.lm.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(maxTokens: 500),
      );
      generateStopwatch.stop();

      debugPrint(
          '[NexusChat] LLM response generated in ${generateStopwatch.elapsedMilliseconds}ms');
      debugPrint('[NexusChat] Response success: ${response.success}');
      debugPrint(
          '[NexusChat] Response length: ${response.response.length} characters');
      if (response.tokensPerSecond > 0) {
        debugPrint(
            '[NexusChat] Tokens per second: ${response.tokensPerSecond.toStringAsFixed(2)}');
      }
      if (response.timeToFirstTokenMs > 0) {
        debugPrint(
            '[NexusChat] Time to first token: ${response.timeToFirstTokenMs}ms');
      }

      if (response.success && mounted) {
        setState(() {
          _messages.add(ChatMessageModel(
            content: response.response,
            role: 'assistant',
            timestamp: DateTime.now(),
            sources: sources.isNotEmpty ? sources : null,
          ));
        });
        debugPrint(
            '[NexusChat] Response added to chat with ${sources.length} sources');
        _scrollToBottom();
      } else {
        debugPrint(
            '[NexusChat] WARNING: Response not successful or widget not mounted');
      }

      debugPrint('[NexusChat] ========================================');
    } catch (e, stackTrace) {
      debugPrint('[NexusChat] ERROR generating response: $e');
      debugPrint('[NexusChat] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _messages.add(ChatMessageModel(
            content: 'Sorry, I encountered an error: $e',
            role: 'assistant',
            timestamp: DateTime.now(),
          ));
        });
      }
    } finally {
      setState(() {
        isGenerating = false;
      });
      debugPrint(
          '[NexusChat] _sendMessage() finished, isGenerating set to false');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text('Chat with Nexus'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: const Color(0xFF8CFF9E),
        elevation: 0,
      ),
      body: Column(
        children: [
          if (isLoadingChatModel)
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1A1A1A),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF8CFF9E)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Loading chat model...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: const Color(0xFF8CFF9E).withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start a conversation with Nexus',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ask questions about your knowledge base',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          if (isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1A1A1A),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF8CFF9E)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Nexus is thinking...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF8CFF9E) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.black : Colors.white,
                fontSize: 15,
              ),
            ),
            if (message.sources != null && message.sources!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.source,
                    size: 14,
                    color: const Color(0xFF8CFF9E).withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Sources: ${message.sources!.join(', ')}',
                      style: TextStyle(
                        color: const Color(0xFF8CFF9E).withOpacity(0.7),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !isGenerating && isChatModelLoaded,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: isChatModelLoaded
                    ? 'Type your message...'
                    : 'Loading chat model...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF050505),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8CFF9E),
                  Colors.tealAccent.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed:
                  (!isGenerating && isChatModelLoaded) ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageModel {
  final String content;
  final String role;
  final DateTime timestamp;
  final List<String>? sources;

  ChatMessageModel({
    required this.content,
    required this.role,
    required this.timestamp,
    this.sources,
  });
}
