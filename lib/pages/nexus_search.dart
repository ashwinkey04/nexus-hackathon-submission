import 'package:cactus/cactus.dart';
import 'package:flutter/material.dart';

class NexusSearchPage extends StatefulWidget {
  final CactusRAG rag;

  const NexusSearchPage({
    super.key,
    required this.rag,
  });

  @override
  State<NexusSearchPage> createState() => _NexusSearchPageState();
}

class _NexusSearchPageState extends State<NexusSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<ChunkSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      debugPrint('[NexusSearch] _performSearch() skipped: empty query');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search query')),
      );
      return;
    }

    debugPrint('[NexusSearch] ========================================');
    debugPrint('[NexusSearch] _performSearch() called');
    debugPrint('[NexusSearch] Search query: "$query"');
    debugPrint('[NexusSearch] Query length: ${query.length} characters');

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResults = [];
    });

    try {
      debugPrint('[NexusSearch] Performing RAG search with limit: 10');
      final searchStopwatch = Stopwatch()..start();
      final results = await widget.rag.search(
        text: query,
        limit: 10,
      );
      searchStopwatch.stop();
      
      debugPrint('[NexusSearch] Search completed in ${searchStopwatch.elapsedMilliseconds}ms');
      debugPrint('[NexusSearch] Found ${results.length} results');

      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        final docName = result.chunk.document.target?.fileName ?? 'Unknown';
        final similarity = (result.distance * 100).toStringAsFixed(1);
        debugPrint('[NexusSearch] Result ${i + 1}:');
        debugPrint('[NexusSearch]   - Document: $docName');
        debugPrint('[NexusSearch]   - Similarity: $similarity%');
        debugPrint('[NexusSearch]   - Distance: ${result.distance}');
        debugPrint('[NexusSearch]   - Chunk content length: ${result.chunk.content.length} characters');
        debugPrint('[NexusSearch]   - Content preview: ${result.chunk.content.substring(0, result.chunk.content.length > 150 ? 150 : result.chunk.content.length)}...');
      }

      setState(() {
        _searchResults = results;
      });
      
      debugPrint('[NexusSearch] Search results displayed in UI');
      debugPrint('[NexusSearch] ========================================');
    } catch (e, stackTrace) {
      debugPrint('[NexusSearch] ERROR searching: $e');
      debugPrint('[NexusSearch] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
      debugPrint('[NexusSearch] _performSearch() finished, _isSearching set to false');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        title: const Text('Search Knowledge Base'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: const Color(0xFFCCFFD6),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    enabled: !_isSearching,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search your documents...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF050505),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFCCFFD6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFCCFFD6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.black),
                    onPressed: _isSearching ? null : _performSearch,
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCCFFD6)),
            ),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: const Color(0xFFCCFFD6).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search your knowledge base',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a query to find relevant documents',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try a different search query',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final docName =
            result.chunk.document.target?.fileName ?? 'Unknown Document';
        final similarity = (result.distance * 100).toStringAsFixed(1);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2A2A2A),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFFD6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$similarity% match',
                      style: const TextStyle(
                        color: Color(0xFFCCFFD6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      docName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                result.chunk.content,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

