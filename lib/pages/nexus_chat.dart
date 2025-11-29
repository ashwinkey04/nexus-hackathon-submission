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

  // Processing steps tracking
  final List<ProcessingStep> _processingSteps = [];
  bool _showProcessingSteps = true;

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

  void _addProcessingStep(String step, {String? detail}) {
    setState(() {
      _processingSteps.add(ProcessingStep(
        step: step,
        detail: detail,
        timestamp: DateTime.now(),
      ));
    });
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
      _processingSteps.clear();
    });

    _scrollToBottom();

    try {
      // Step 1: Search RAG for relevant context
      debugPrint('[NexusChat] Step 1: Searching RAG for relevant context...');
      _addProcessingStep('🔄 Generating embedding for query...');
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

      _addProcessingStep(
        '✅ RAG search completed',
        detail:
            'Found ${searchResults.length} relevant chunks in ${(searchStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s',
      );

      // Step 2: Build context from search results
      String context = '';
      List<String> sources = [];

      if (searchResults.isNotEmpty) {
        debugPrint(
            '[NexusChat] Step 2: Building context from search results...');
        _addProcessingStep('📚 Building context from retrieved chunks...');

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

          _addProcessingStep(
            '  📄 Chunk ${i + 1}: $docName',
            detail: 'Similarity: $similarity%',
          );
        }
        debugPrint('[NexusChat] Context built: ${context.length} characters');
        _addProcessingStep(
          '✅ Context built',
          detail: '${context.length} characters from ${sources.length} sources',
        );
      } else {
        debugPrint(
            '[NexusChat] No relevant chunks found, proceeding without context');
        _addProcessingStep('ℹ️ No relevant chunks found in knowledge base');
      }

      // Step 3: Build messages for LLM
      debugPrint('[NexusChat] Step 3: Building messages for LLM...');
      _addProcessingStep('🔧 Building prompt with context...');

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

      _addProcessingStep(
        '✅ Prompt built',
        detail: '${messages.length} messages total',
      );

      // Step 4: Generate response
      debugPrint('[NexusChat] Step 4: Generating LLM response...');
      _addProcessingStep('🤖 Generating response with LLM...');

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

      _addProcessingStep(
        '✅ Response generated',
        detail:
            '${response.response.length} characters in ${(generateStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s • ${response.tokensPerSecond.toStringAsFixed(1)} tokens/s',
      );

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
      body: SafeArea(
        child: Column(
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
            if (_processingSteps.isNotEmpty) _buildProcessingSteps(),
            if (isGenerating)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            _MessageContentWidget(
              content: message.content,
              isUser: isUser,
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

  Widget _buildProcessingSteps() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8CFF9E).withOpacity(0.3),
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
                    color: const Color(0xFF8CFF9E),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Processing Steps',
                    style: TextStyle(
                      color: Color(0xFF8CFF9E),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isGenerating)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8CFF9E)),
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

class _MessageContentWidget extends StatefulWidget {
  final String content;
  final bool isUser;

  const _MessageContentWidget({
    required this.content,
    required this.isUser,
  });

  @override
  State<_MessageContentWidget> createState() => _MessageContentWidgetState();
}

class _MessageContentWidgetState extends State<_MessageContentWidget> {
  final List<bool> _expandedThinkBlocks = [];

  @override
  Widget build(BuildContext context) {
    final parsedContent = _parseContent(widget.content);

    // Initialize expanded states if needed
    if (_expandedThinkBlocks.length != parsedContent.thinkBlocks.length) {
      _expandedThinkBlocks.clear();
      _expandedThinkBlocks.addAll(
        List.filled(parsedContent.thinkBlocks.length, false),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < parsedContent.segments.length; i++) ...[
          if (parsedContent.segments[i].isThinkBlock)
            _buildThinkBlock(
              parsedContent.segments[i].content,
              parsedContent.segments[i].thinkIndex!,
            )
          else if (parsedContent.segments[i].content.trim().isNotEmpty)
            Text(
              parsedContent.segments[i].content,
              style: TextStyle(
                color: widget.isUser ? Colors.black : Colors.white,
                fontSize: 15,
              ),
            ),
          if (i < parsedContent.segments.length - 1 &&
              parsedContent.segments[i].content.trim().isNotEmpty)
            const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildThinkBlock(String content, int index) {
    final isExpanded = _expandedThinkBlocks[index];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: widget.isUser
            ? Colors.black.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isUser
              ? Colors.black.withOpacity(0.2)
              : const Color(0xFF8CFF9E).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedThinkBlocks[index] = !_expandedThinkBlocks[index];
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: widget.isUser
                        ? Colors.black.withOpacity(0.6)
                        : const Color(0xFF8CFF9E).withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '💭 Thinking process',
                    style: TextStyle(
                      color: widget.isUser
                          ? Colors.black.withOpacity(0.7)
                          : const Color(0xFF8CFF9E).withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(
              color: widget.isUser
                  ? Colors.black.withOpacity(0.1)
                  : Colors.white.withOpacity(0.1),
              height: 1,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                content,
                style: TextStyle(
                  color: widget.isUser
                      ? Colors.black.withOpacity(0.7)
                      : Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _ParsedContent _parseContent(String content) {
    final segments = <_ContentSegment>[];
    final thinkBlocks = <String>[];

    // Regular expression to match <think>...</think> blocks
    final thinkRegex = RegExp(r'<think>([\s\S]*?)<\/think>', multiLine: true);

    int lastEnd = 0;
    int thinkIndex = 0;

    for (final match in thinkRegex.allMatches(content)) {
      // Add text before the think block
      if (match.start > lastEnd) {
        final beforeText = content.substring(lastEnd, match.start);
        segments.add(_ContentSegment(
          content: beforeText,
          isThinkBlock: false,
        ));
      }

      // Add the think block
      final thinkContent = match.group(1)?.trim() ?? '';
      thinkBlocks.add(thinkContent);
      segments.add(_ContentSegment(
        content: thinkContent,
        isThinkBlock: true,
        thinkIndex: thinkIndex,
      ));
      thinkIndex++;

      lastEnd = match.end;
    }

    // Add remaining text after the last think block
    if (lastEnd < content.length) {
      final remainingText = content.substring(lastEnd);
      segments.add(_ContentSegment(
        content: remainingText,
        isThinkBlock: false,
      ));
    }

    // If no think blocks were found, return the entire content as a single segment
    if (segments.isEmpty) {
      segments.add(_ContentSegment(
        content: content,
        isThinkBlock: false,
      ));
    }

    return _ParsedContent(segments: segments, thinkBlocks: thinkBlocks);
  }
}

class _ContentSegment {
  final String content;
  final bool isThinkBlock;
  final int? thinkIndex;

  _ContentSegment({
    required this.content,
    required this.isThinkBlock,
    this.thinkIndex,
  });
}

class _ParsedContent {
  final List<_ContentSegment> segments;
  final List<String> thinkBlocks;

  _ParsedContent({
    required this.segments,
    required this.thinkBlocks,
  });
}
