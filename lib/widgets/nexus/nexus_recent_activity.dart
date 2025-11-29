import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';

class NexusRecentActivity extends StatelessWidget {
  final DatabaseStats? dbStats;
  final List<Document>? recentDocuments;
  final Color cardDark;
  final Color accentPurple;
  final Color accentGreen;
  final VoidCallback onViewAllTap;

  const NexusRecentActivity({
    super.key,
    required this.dbStats,
    this.recentDocuments,
    required this.cardDark,
    required this.accentPurple,
    required this.accentGreen,
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onPressed: onViewAllTap,
              child: Text(
                'View All',
                style: TextStyle(color: accentGreen),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Show actual documents or empty state
        Expanded(
          child: (recentDocuments == null || recentDocuments!.isEmpty)
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount:
                      recentDocuments!.length > 5 ? 5 : recentDocuments!.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildDocumentItem(recentDocuments![index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              color: Colors.grey.withOpacity(0.3),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No documents yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Manage Knowledge" to add documents',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentItem(Document doc) {
    // Determine icon and color based on file path/type
    IconData icon;
    Color color;
    String source;

    if (doc.filePath.startsWith('demo_data/')) {
      icon = Icons.cloud;
      color = Colors.blueAccent;
      source = 'Demo Data';
    } else if (doc.filePath.startsWith('manual_entry/')) {
      icon = Icons.edit_note;
      color = accentPurple;
      source = 'Manual Entry';
    } else if (doc.filePath.endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.redAccent;
      source = 'PDF';
    } else if (doc.filePath.endsWith('.txt')) {
      icon = Icons.description;
      color = accentGreen;
      source = 'Text File';
    } else if (doc.filePath.endsWith('.md')) {
      icon = Icons.description;
      color = accentGreen;
      source = 'Markdown';
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
      source = 'File';
    }

    // Format file size
    final fileSize = doc.fileSize ?? 0;
    String sizeStr;
    if (fileSize < 1024) {
      sizeStr = '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      sizeStr = '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      sizeStr = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      source,
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      ' • ',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    Text(
                      sizeStr,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
